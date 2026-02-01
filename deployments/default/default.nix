{ ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);
in {
  vps.provider = server.provider;
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "default";
}
