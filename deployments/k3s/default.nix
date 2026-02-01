{ config, lib, pkgs, ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);
in {
  vps.provider = server.provider;
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "k3s";

  networking.firewall.allowedTCPPorts = [ 6443 80 443 ];

  services.k3s = {
    enable = true;
    role = "server";
    manifests = {
      hello-nginx.source = ./manifests/hello-nginx.yaml;
    };
  };

  environment.systemPackages = [ pkgs.kubectl ];
}
