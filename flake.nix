{
  description = "Opinionated NixOS VPS template with ephemeral root, impermanence, and agenix secrets";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
    # Export modules for consumers
    nixosModules = {
      base = ./nix/modules/platforms/base.nix;
      vultr = ./nix/modules/platforms/vultr.nix;
      hardening = ./nix/modules/security/hardening.nix;
    };

    # Convenience bundle of all modules
    nixosModules.default = { ... }: {
      imports = [
        self.nixosModules.base
        self.nixosModules.vultr
        self.nixosModules.hardening
      ];
    };

    devShells = forAllSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.opentofu
            pkgs.age
            pkgs.just
            pkgs.jq
            pkgs.curl
          ];
          shellHook = ''
            alias terraform=tofu
            echo "nix-vps-template dev shell"
            echo "  tofu: $(tofu version -json | jq -r .terraform_version)"
            echo "  just: $(just --version)"
            echo "  age:  $(age --version)"
          '';
        };
      });
  };
}
