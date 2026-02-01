{ config, lib, pkgs, ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);
in {
  vps.provider = server.provider;
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "nixginx";

  services.nginx = {
    enable = true;
    virtualHosts.${server.ip} = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        root = "/var/www/hello";
        index = "index.html";
      };
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

  system.activationScripts.createHelloWorld = lib.stringAfter [ "var" ] ''
    mkdir -p /var/www/hello
    cat > /var/www/hello/index.html << 'EOF'
    <!DOCTYPE html>
    <html>
    <head><title>nixginx</title></head>
    <body>
      <h1>Hello, World!</h1>
      <p>Served with nginx + Let's Encrypt IP certificate (shortlived profile)</p>
    </body>
    </html>
    EOF
  '';
}
