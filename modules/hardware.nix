# Generic VPS hardware config using labels
{ modulesPath, ... }: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

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

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  zramSwap.enable = true;
}
