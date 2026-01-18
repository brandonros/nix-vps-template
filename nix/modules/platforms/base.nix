# Base VPS configuration - shared across all cloud providers
{ config, lib, pkgs, sshPubKey, ... }:

with lib;

{
  options.vps = {
    hostname = mkOption {
      type = types.str;
      default = "nixos";
      description = "System hostname";
    };

    tmpfsSize = mkOption {
      type = types.str;
      default = "512M";
      description = "Size of tmpfs root filesystem";
    };

    passwordSecretFile = mkOption {
      type = types.path;
      description = "Path to age-encrypted password hash file";
    };

    persistDirs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional directories to persist across reboots";
    };

    persistFiles = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional files to persist across reboots";
    };
  };

  config = {
    # Agenix identity path (before impermanence bind mount)
    age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

    # Agenix secret for password hash
    age.secrets.passwordHash = {
      file = config.vps.passwordSecretFile;
      owner = "root";
      mode = "0400";
    };

    # Ephemeral root filesystem
    disko.devices.nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "defaults" "size=${config.vps.tmpfsSize}" "mode=755" ];
    };

    # Ensure these are available early for boot
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/nix".neededForBoot = true;

    # Impermanence - declare what survives reboots
    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
        "/etc/ssh"
      ] ++ config.vps.persistDirs;
      files = [
        "/etc/machine-id"
      ] ++ config.vps.persistFiles;
    };

    # Boot (UEFI with systemd-boot)
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Networking
    networking.hostName = config.vps.hostname;
    networking.useDHCP = true;

    # Root user
    users.users.root = {
      openssh.authorizedKeys.keys = [ sshPubKey ];
      hashedPasswordFile = config.age.secrets.passwordHash.path;
    };

    # Normal user with sudo
    users.users.user = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ sshPubKey ];
      hashedPasswordFile = config.age.secrets.passwordHash.path;
    };

    # SSH
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = true;
      };
    };

    # Auto-upgrades
    system.autoUpgrade = {
      enable = true;
      allowReboot = false;
    };

    # System
    system.stateVersion = "25.11";
  };
}
