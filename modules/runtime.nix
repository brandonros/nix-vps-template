# Runtime config (SSH, users, network)
{ config, lib, ... }:

with lib;

{
  options.vps = {
    sshPubKey = mkOption {
      type = types.str;
      description = "SSH public key for root and user access";
    };
    hostname = mkOption {
      type = types.str;
      default = "nixos-vps";
      description = "Server hostname";
    };
  };

  config = {
    networking.hostName = config.vps.hostname;
    networking.useDHCP = true;
    networking.firewall.allowedTCPPorts = [ 22 ];

    users.users.root.openssh.authorizedKeys.keys = [ config.vps.sshPubKey ];
    users.users.user = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ config.vps.sshPubKey ];
    };

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
      settings.PasswordAuthentication = false;
    };

    security.sudo.wheelNeedsPassword = false;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    system.stateVersion = "23.11";
  };
}
