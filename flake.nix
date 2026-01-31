{
  description = "NixOS VPS deployments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      mkDeployment = name: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.default
          ./deployments/${name}
        ];
      };
    in {
      # Reusable module for external consumers
      nixosModules.default = ./modules;

      # All deployments
      nixosConfigurations = {
        default  = mkDeployment "default";
        ez3proxy = mkDeployment "ez3proxy";
        nixginx  = mkDeployment "nixginx";
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
