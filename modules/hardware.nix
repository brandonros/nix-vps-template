# Vultr VPS hardware config
{ modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  # Disk/storage drivers for various hypervisors - all force-loaded
  boot.initrd.kernelModules = [
    "virtio_pci" "virtio_blk" "virtio_scsi"   # KVM/Vultr
    "ahci" "sd_mod" "nvme"                    # Generic
    "xen_blkfront"                            # Xen
    "vmw_pvscsi"                              # VMware
    "ata_piix" "uhci_hcd"                     # Legacy
  ];
  boot.tmp.cleanOnBoot = true;

  # Standard cloud VPS layout: vda1=EFI, vda2=root
  fileSystems."/" = {
    device = "/dev/vda2";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/vda1";
    fsType = "vfat";
  };

  zramSwap.enable = true;
}
