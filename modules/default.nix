# Base NixOS module for cloud VPS (KVM guest, SSH, users, firewall)
{ config, lib, modulesPath, ... }:

with lib;

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

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
    # Nix
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    system.stateVersion = "23.11";

    # Boot
    boot.loader.efi.efiSysMountPoint = "/boot/efi";
    boot.loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
    boot.initrd.kernelModules = [
      "virtio_pci" "virtio_blk" "virtio_scsi"   # KVM/QEMU
      "ahci" "sd_mod" "nvme"                    # Generic
      "xen_blkfront"                            # Xen
      "vmw_pvscsi"                              # VMware
      "ata_piix" "uhci_hcd"                     # Legacy
    ];
    boot.tmp.cleanOnBoot = true;

    # Disks (standard cloud VPS layout: vda1=EFI, vda2=root)
    fileSystems."/" = { device = "/dev/vda2"; fsType = "ext4"; };
    fileSystems."/boot/efi" = { device = "/dev/vda1"; fsType = "vfat"; };
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
