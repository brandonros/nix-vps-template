# Base NixOS module for VPS deployments
# Import this in your flake's nixosConfigurations for nixos-rebuild targets
{ sshPubKey, hostname ? "nixos-vps", ... }: {
  imports = [ (import ./runtime.nix { inherit sshPubKey hostname; }) ];

  # Boot (EFI, matches raw-efi image layout)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "sd_mod" ];

  # Filesystem (matches raw-efi image layout)
  fileSystems."/" = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/disk/by-label/ESP"; fsType = "vfat"; };
}
