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
      sshPubKey = builtins.readFile ./assets/deploy-key.pub;
    in {
      # Reusable module for runtime config
      nixosModules.default = import ./modules/base.nix;

      # Example NixOS configuration (for nixos-rebuild)
      nixosConfigurations.nixos-vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ (self.nixosModules.default { inherit sshPubKey; }) ];
      };

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
