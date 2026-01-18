# Security hardening configuration
{ config, lib, pkgs, ... }:

with lib;

{
  options.hardening = {
    enableFail2ban = mkOption {
      type = types.bool;
      default = true;
      description = "Enable fail2ban for brute-force protection";
    };

    sshPort = mkOption {
      type = types.port;
      default = 22;
      description = "SSH port to allow through firewall";
    };
  };

  config = {
    # Firewall - SSH always allowed
    networking.firewall.allowedTCPPorts = [ config.hardening.sshPort ];

    # Sudo without password for wheel group
    security.sudo.wheelNeedsPassword = false;

    # Fail2ban
    services.fail2ban.enable = config.hardening.enableFail2ban;

    # Persist fail2ban state if enabled
    vps.persistDirs = mkIf config.hardening.enableFail2ban [
      "/var/lib/fail2ban"
    ];
  };
}
