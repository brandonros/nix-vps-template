# Base NixOS module for cloud VPS (KVM guest, SSH, users, firewall)
{ config, lib, modulesPath, ... }:

with lib;

let
  cfg = config.vps;

  # Provider presets: maps provider -> { bootMode, disk, efiPartition }
  providerPresets = {
    vultr = {
      bootMode = "efi";
      disk = "/dev/vda";
      rootPartition = "/dev/vda2";
      efiPartition = "/dev/vda1";
    };
    hetzner = {
      bootMode = "bios";
      disk = "/dev/sda";
      rootPartition = "/dev/sda1";
      efiPartition = null;
    };
  };

  preset = providerPresets.${cfg.provider};
  isEfi = preset.bootMode == "efi";
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  options.vps = {
    provider = mkOption {
      type = types.enum [ "vultr" "hetzner" ];
      default = "vultr";
      description = "Cloud provider (determines boot mode and disk layout)";
    };
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
    # Nix
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    nix.settings.trusted-users = [ "root" "@wheel" ];
    nix.settings.extra-substituters = [ "https://brandonros.cachix.org" ];
    nix.settings.extra-trusted-public-keys = [
      "brandonros.cachix.org-1:2VlkqIIKqlZ0oWyA4B+R8oa4lGf1YPJSrKnVnCtVjmU="
    ];
    system.stateVersion = "26.05";

    # Boot (provider-dependent)
    boot.loader.efi.efiSysMountPoint = mkIf isEfi "/boot/efi";
    boot.loader.grub = {
      enable = true;
      efiSupport = isEfi;
      efiInstallAsRemovable = isEfi;
      device = if isEfi then "nodev" else preset.disk;
    };
    boot.initrd.kernelModules = [
      "virtio_pci" "virtio_blk" "virtio_scsi"   # KVM/QEMU
      "ahci" "sd_mod" "nvme"                    # Generic
      "xen_blkfront"                            # Xen
      "vmw_pvscsi"                              # VMware
      "ata_piix" "uhci_hcd"                     # Legacy
    ];
    boot.tmp.cleanOnBoot = true;

    # Disks (provider-dependent layout)
    fileSystems."/" = { device = preset.rootPartition; fsType = "ext4"; };
    fileSystems."/boot/efi" = mkIf isEfi { device = preset.efiPartition; fsType = "vfat"; };
    zramSwap.enable = true;

    # Network
    networking.hostName = config.vps.hostname;
    networking.useDHCP = true;
    networking.firewall.allowedTCPPorts = [ 22 ];

    # Users + security
    users.users.root.openssh.authorizedKeys.keys = [ config.vps.sshPubKey ];
    users.users.user = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ config.vps.sshPubKey ];
    };
    security.sudo.wheelNeedsPassword = false;

    # SSH
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "prohibit-password";
      settings.PasswordAuthentication = false;
    };
  };
}
