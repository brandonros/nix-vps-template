{
  description = "Opinionated NixOS VPS template with ephemeral root, impermanence, and agenix secrets";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, disko, agenix, impermanence }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    in {
    # Export individual modules for fine-grained control
    nixosModules = {
      base = ./nix/modules/platforms/base.nix;
      vultr = ./nix/modules/platforms/vultr.nix;
      hardening = ./nix/modules/security/hardening.nix;
    };

    # Convenience bundle with all dependencies included
    nixosModules.default = { ... }: {
      imports = [
        disko.nixosModules.disko
        agenix.nixosModules.default
        impermanence.nixosModules.impermanence
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
