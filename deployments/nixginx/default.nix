{ config, lib, pkgs, ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);

  # Build the frontend (vite -> dist/)
  frontend = pkgs.buildNpmPackage {
    pname = "nixginx-frontend";
    version = "0.0.1";
    src = ./.;
    npmDepsHash = "sha256-VWIghIugSBkMDOB5ScJqwBC/WVYAVCUBmGwnwGgqzas=";
    buildPhase = ''
      npm run build --workspace=frontend
    '';
    installPhase = ''
      mkdir -p $out
      cp -r apps/frontend/dist/* $out/
    '';
  };

  # Package the backend (no build, just need node_modules + source)
  backend = pkgs.buildNpmPackage {
    pname = "nixginx-backend";
    version = "0.0.1";
    src = ./.;
    npmDepsHash = "sha256-VWIghIugSBkMDOB5ScJqwBC/WVYAVCUBmGwnwGgqzas=";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
      # remove workspace symlinks (they point to ../apps/*)
      rm -rf $out/node_modules/{shared,frontend,backend}
      cp -r apps/backend/* $out/
      cp -r apps/shared $out/node_modules/
    '';
  };
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
        root = frontend;
        tryFiles = "$uri $uri/ /index.html"; # SPA fallback
      };
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:3000/"; # trailing slashes strip /api prefix
      };
    };
  };

  systemd.services.backend = {
    description = "nixginx backend";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nodejs}/bin/node ${backend}/src/index.js";
      Restart = "always";

      # User isolation
      DynamicUser = true;
      RemoveIPC = true;

      # Filesystem isolation
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadOnlyPaths = [ "/" ];
      UMask = "0077";

      # Device/kernel/system isolation
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      ProtectHostname = true;
      ProtectClock = true;

      # Privilege isolation
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictSUIDSGID = true;
      RestrictRealtime = true;

      # Execution restrictions
      SystemCallArchitectures = "native";
      RestrictNamespaces = true;
      LockPersonality = true;

      # Resource limits
      MemoryMax = "256M";
      CPUQuota = "100%";
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
