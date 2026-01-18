{
  description = "Simple NixOS VPS template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
    nixosModules.default = { sshPubKey, hostname ? "nixos-vps", ... }: {
      imports = [ disko.nixosModules.disko ];

      # Disk layout (Vultr/KVM)
      disko.devices.disk.main = {
        device = "/dev/vda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
            };
            root = {
              size = "100%";
              content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
            };
          };
        };
      };

      # Boot
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "ahci" "sd_mod" ];

      # Network
      networking.hostName = hostname;
      networking.useDHCP = true;
      networking.firewall.allowedTCPPorts = [ 22 ];

      # Users - SSH key only, no passwords
      users.users.root.openssh.authorizedKeys.keys = [ sshPubKey ];
      users.users.user = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [ sshPubKey ];
      };

      # SSH
      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "prohibit-password";
        settings.PasswordAuthentication = false;
      };

      # Sudo without password
      security.sudo.wheelNeedsPassword = false;

      system.stateVersion = "25.11";
    };

    devShells = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = [ pkgs.opentofu pkgs.just ];
        };
      });
  };
}
