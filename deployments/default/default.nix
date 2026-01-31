{ ... }:
{
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "default";
}
