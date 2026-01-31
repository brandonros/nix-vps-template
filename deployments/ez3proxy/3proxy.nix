# 3proxy over VPN with network namespace isolation
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.proxy;

  # Script to set up the network namespace and veth pair
  setupNetns = pkgs.writeShellScript "setup-vpn-netns" ''
    set -e

    # Create namespace if it doesn't exist
    ${pkgs.iproute2}/bin/ip netns add vpn 2>/dev/null || true

    # Clean up existing veth if present
    ${pkgs.iproute2}/bin/ip link del veth-vpn 2>/dev/null || true

    # Create veth pair
    ${pkgs.iproute2}/bin/ip link add veth-vpn type veth peer name veth-vpn-peer
    ${pkgs.iproute2}/bin/ip link set veth-vpn-peer netns vpn

    # Configure host side
    ${pkgs.iproute2}/bin/ip addr add 10.200.200.1/24 dev veth-vpn
    ${pkgs.iproute2}/bin/ip link set veth-vpn up

    # Configure namespace side
    ${pkgs.iproute2}/bin/ip netns exec vpn ${pkgs.iproute2}/bin/ip addr add 10.200.200.2/24 dev veth-vpn-peer
    ${pkgs.iproute2}/bin/ip netns exec vpn ${pkgs.iproute2}/bin/ip link set veth-vpn-peer up
    ${pkgs.iproute2}/bin/ip netns exec vpn ${pkgs.iproute2}/bin/ip link set lo up

    # Default route in namespace via host (before VPN is up)
    ${pkgs.iproute2}/bin/ip netns exec vpn ${pkgs.iproute2}/bin/ip route add default via 10.200.200.1

    # Enable IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # NAT for namespace to reach internet (needed for VPN connection)
    ${pkgs.iptables}/bin/iptables -t nat -C POSTROUTING -s 10.200.200.0/24 -j MASQUERADE 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.200.200.0/24 -j MASQUERADE

    # SNAT for traffic entering namespace (so responses route back via veth, not VPN)
    ${pkgs.iptables}/bin/iptables -t nat -C POSTROUTING -o veth-vpn -j MASQUERADE 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -o veth-vpn -j MASQUERADE

    # Port forward to namespace
    ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -p tcp --dport ${toString cfg.httpPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.httpPort} 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport ${toString cfg.httpPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.httpPort}
    ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -p tcp --dport ${toString cfg.socksPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.socksPort} 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport ${toString cfg.socksPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.socksPort}

    # Allow forwarding to/from namespace
    ${pkgs.iptables}/bin/iptables -C FORWARD -i veth-vpn -j ACCEPT 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -A FORWARD -i veth-vpn -j ACCEPT
    ${pkgs.iptables}/bin/iptables -C FORWARD -o veth-vpn -j ACCEPT 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -A FORWARD -o veth-vpn -j ACCEPT
  '';

  teardownNetns = pkgs.writeShellScript "teardown-vpn-netns" ''
    ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport ${toString cfg.httpPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.httpPort} 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport ${toString cfg.socksPort} -j DNAT --to-destination 10.200.200.2:${toString cfg.socksPort} 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.200.200.0/24 -j MASQUERADE 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o veth-vpn -j MASQUERADE 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D FORWARD -i veth-vpn -j ACCEPT 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D FORWARD -o veth-vpn -j ACCEPT 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip link del veth-vpn 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip netns del vpn 2>/dev/null || true
  '';

  # 3proxy config file
  proxyConfig = pkgs.writeText "3proxy.cfg" ''
    nserver 1.1.1.1
    nserver 8.8.8.8
    nscache 65536

    timeouts 1 5 30 60 180 1800 15 60

    ${concatStringsSep "\n" cfg.users}

    auth strong
    allow *

    proxy -p${toString cfg.httpPort}
    socks -p${toString cfg.socksPort}
  '';

in {
  options.proxy = {
    httpPort = mkOption {
      type = types.port;
      default = 3128;
      description = "HTTP proxy port";
    };

    socksPort = mkOption {
      type = types.port;
      default = 1080;
      description = "SOCKS5 proxy port";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of user:CL:password entries";
      example = [ "users testuser:CL:testpass123" ];
    };

    vpn = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Route proxy traffic through VPN";
      };

      configFile = mkOption {
        type = types.path;
        description = "Path to OpenVPN config file (.ovpn)";
      };

      authFile = mkOption {
        type = types.str;
        default = "/etc/secrets/vpn-auth";
        description = "Path to file containing username (line 1) and password (line 2)";
      };
    };
  };

  config = mkMerge [
    # VPN + namespace mode
    (mkIf cfg.vpn.enable {
      # Network namespace setup
      systemd.services.vpn-netns = {
        description = "VPN Network Namespace";
        before = [ "openvpn-vpn.service" "_3proxy.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = setupNetns;
          ExecStop = teardownNetns;
        };
      };

      # OpenVPN in the namespace
      systemd.services.openvpn-vpn = {
        description = "OpenVPN in VPN namespace";
        after = [ "vpn-netns.service" "network-online.target" ];
        requires = [ "vpn-netns.service" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "notify";
          NetworkNamespacePath = "/run/netns/vpn";
          ExecStart = "${pkgs.openvpn}/bin/openvpn --config ${cfg.vpn.configFile} --auth-user-pass ${cfg.vpn.authFile} --auth-nocache --script-security 2";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # 3proxy in the namespace
      systemd.services._3proxy = {
        description = "3proxy in VPN namespace";
        after = [ "openvpn-vpn.service" ];
        requires = [ "openvpn-vpn.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          NetworkNamespacePath = "/run/netns/vpn";
          ExecStart = "${pkgs._3proxy}/bin/3proxy ${proxyConfig}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      networking.firewall.allowedTCPPorts = [
        cfg.httpPort
        cfg.socksPort
      ];
    })

    # Non-VPN mode (original behavior)
    (mkIf (!cfg.vpn.enable) {
      services._3proxy = {
        enable = true;
        services = [
          {
            type = "proxy";
            bindPort = cfg.httpPort;
            auth = [ "strong" ];
            acl = [{ rule = "allow"; users = [ "*" ]; }];
          }
          {
            type = "socks";
            bindPort = cfg.socksPort;
            auth = [ "strong" ];
            acl = [{ rule = "allow"; users = [ "*" ]; }];
          }
        ];
        extraConfig = concatStringsSep "\n" cfg.users;
      };

      networking.firewall.allowedTCPPorts = [
        cfg.httpPort
        cfg.socksPort
      ];
    })
  ];
}
