# Vultr-specific VPS configuration
{ config, lib, pkgs, ... }:

with lib;

{
  options.vultr = {
    diskDevice = mkOption {
      type = types.str;
      default = "/dev/vda";
      description = "Primary disk device path";
    };

    nixPartitionSize = mkOption {
      type = types.str;
      default = "20G";
      description = "Size of /nix partition";
    };
  };

  config = {
    # Virtio drivers for Vultr/KVM
    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "ahci"
      "sd_mod"
    ];

    # Disk layout for Vultr VPS
    disko.devices.disk.main = {
      device = config.vultr.diskDevice;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          nix = {
            size = config.vultr.nixPartitionSize;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
            };
          };
          persist = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/persist";
            };
          };
        };
      };
    };
  };
}
