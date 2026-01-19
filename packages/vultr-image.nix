# Vultr base image (raw-efi format)
# Build with: nix build .#vultr-image
{ nixos-generators, sshPubKey }:

nixos-generators.nixosGenerate {
  system = "x86_64-linux";
  format = "raw-efi";
  modules = [
    # Runtime config (SSH, users, network, nix)
    (import ../modules/runtime.nix { inherit sshPubKey; })
    # Boot config for image (raw-efi handles disk layout)
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "sd_mod" ];
    }
  ];
}
