# 3proxy over VPN with network namespace isolation
{ config, lib, pkgs, ... }:

let
  server = builtins.fromJSON (builtins.readFile ./server.json);

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
    ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -p tcp --dport 3128 -j DNAT --to-destination 10.200.200.2:3128 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport 3128 -j DNAT --to-destination 10.200.200.2:3128
    ${pkgs.iptables}/bin/iptables -t nat -C PREROUTING -p tcp --dport 1080 -j DNAT --to-destination 10.200.200.2:1080 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -t nat -A PREROUTING -p tcp --dport 1080 -j DNAT --to-destination 10.200.200.2:1080

    # Allow forwarding to/from namespace
    ${pkgs.iptables}/bin/iptables -C FORWARD -i veth-vpn -j ACCEPT 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -A FORWARD -i veth-vpn -j ACCEPT
    ${pkgs.iptables}/bin/iptables -C FORWARD -o veth-vpn -j ACCEPT 2>/dev/null || \
      ${pkgs.iptables}/bin/iptables -A FORWARD -o veth-vpn -j ACCEPT
  '';

  teardownNetns = pkgs.writeShellScript "teardown-vpn-netns" ''
    ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport 3128 -j DNAT --to-destination 10.200.200.2:3128 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport 1080 -j DNAT --to-destination 10.200.200.2:1080 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.200.200.0/24 -j MASQUERADE 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -o veth-vpn -j MASQUERADE 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D FORWARD -i veth-vpn -j ACCEPT 2>/dev/null || true
    ${pkgs.iptables}/bin/iptables -D FORWARD -o veth-vpn -j ACCEPT 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip link del veth-vpn 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip netns del vpn 2>/dev/null || true
  '';

  proxyConfig = pkgs.writeText "3proxy.cfg" ''
    nserver 1.1.1.1
    nserver 8.8.8.8
    nscache 65536
    timeouts 1 5 30 60 180 1800 15 60

    users testuser:CL:testpass123

    auth strong
    allow *

    proxy -p3128
    socks -p1080
  '';

in {
  vps.provider = server.provider;
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "ez3proxy";

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

  systemd.services.openvpn-vpn = {
    description = "OpenVPN in VPN namespace";
    after = [ "vpn-netns.service" "network-online.target" ];
    requires = [ "vpn-netns.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      NetworkNamespacePath = "/run/netns/vpn";
      ExecStart = "${pkgs.openvpn}/bin/openvpn --config ${./openvpn/us6761.nordvpn.com.tcp.ovpn} --auth-user-pass /etc/secrets/vpn-auth --auth-nocache --script-security 2";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

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

  networking.firewall.allowedTCPPorts = [ 3128 1080 ];
}
