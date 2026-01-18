# nix-vps-template

Simple NixOS VPS template with Vultr + nixos-anywhere.

## Quick Start

```bash
nix develop
just keygen   # generate SSH key
just go       # deploy + wait + bootstrap + rebuild
just ssh      # connect
just destroy  # tear down
```

## Usage as a Module

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-vps-template.url = "github:brandonros/nix-vps-template";
  };

  outputs = { nixpkgs, nix-vps-template, ... }: {
    nixosConfigurations.my-vps = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { sshPubKey = builtins.readFile ./secrets/deploy-key.pub; };
      modules = [
        nix-vps-template.nixosModules.default
        { networking.hostName = "my-vps"; }
      ];
    };
  };
}
```

## Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `hostname` | `"nixos-vps"` | Instance hostname |
| `plan` | `"vc2-2c-4gb"` | Vultr plan |
| `region` | `"atl"` | Vultr region |
| `ssh_public_key` | - | SSH public key content |

## Requirements

- Nix with flakes
- `VULTR_API_KEY` environment variable
