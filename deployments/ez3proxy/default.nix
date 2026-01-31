{ config, lib, pkgs, ... }:
{
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "ez3proxy";

  imports = [ ./3proxy.nix ];

  proxy.users = [
    "users testuser:CL:testpass123"
  ];

  proxy.vpn = {
    enable = true;
    configFile = ./openvpn/us6761.nordvpn.com.tcp.ovpn;
  };
}
