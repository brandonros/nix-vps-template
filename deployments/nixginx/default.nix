{ config, lib, pkgs, ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);
  webroot = ./assets;
in {
  vps.provider = server.provider;
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "nixginx";

  services.nginx = {
    enable = true;
    virtualHosts.${server.ip} = {
      forceSSL = true;
      enableACME = true;
      locations."/".root = webroot;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "ceyami6672@1200b.com";
    certs.${server.ip} = {
      profile = "shortlived";
      # workaround: acme: error: 400 :: urn:ietf:params:acme:error:badCSR :: Error finalizing order :: CSR contains IP address in Common Name
      extraLegoFlags = [ "--disable-cn" ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

}
