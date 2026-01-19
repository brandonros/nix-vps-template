{
  description = "Simple NixOS VPS template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
      # Reusable module - downstream projects import this
      nixosModules.default = { sshPubKey, hostname ? "nixos-vps" }:
        import ./modules/runtime.nix { inherit sshPubKey hostname; };

      # Standalone config for testing (uses local key)
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./modules/runtime.nix {
            sshPubKey = builtins.readFile ./keys/deploy-key.pub;
          })
        ];
      };

      # Dev shell
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            packages = [ pkgs.opentofu pkgs.just ];
          };
        });
    };
}
