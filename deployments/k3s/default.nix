{ config, lib, pkgs, ... }:
{
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "k3s";

  networking.firewall.allowedTCPPorts = [ 6443 80 443 ];

  services.k3s = {
    enable = true;
    role = "server";
    manifests = {
      hello-nginx = ./manifests/hello-nginx.yaml;
    };
  };

  environment.systemPackages = [ pkgs.kubectl ];
}
