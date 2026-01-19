{
  description = "Simple NixOS VPS template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      sshPubKey = builtins.readFile ./keys/deploy-key.pub;
    in {
      # Reusable module for runtime config (SSH, users, network, nix settings)
      # Projects import this - no boot/filesystem config (snapshot handles that)
      nixosModules.default = { sshPubKey, hostname ? "nixos-vps" }:
        import ./modules/runtime.nix { inherit sshPubKey hostname; };

      # Dev shell
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.opentofu pkgs.just ];
          };
        });

      # Pre-built Vultr image
      packages.x86_64-linux.vultr-image = import ./packages/vultr-image.nix {
        inherit nixos-generators sshPubKey;
      };
    };
}
