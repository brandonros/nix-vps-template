# nix-vps-template

NixOS VPS template with ephemeral root, agenix secrets, and Vultr provisioning.

## Features

- **Ephemeral root** - tmpfs root via [impermanence](https://github.com/nix-community/impermanence), reboots wipe everything not explicitly persisted
- **Secrets** - [agenix](https://github.com/ryantm/agenix) for age-encrypted secrets
- **Infrastructure** - OpenTofu + [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) for zero-touch provisioning
- **Hardening** - fail2ban, firewall, passwordless sudo for wheel

## Usage

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
        {
          vps.hostname = "my-vps";
          vps.passwordSecretFile = ./secrets/password-hash.age;
        }
      ];
    };
  };
}
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `vps.hostname` | `"nixos"` | System hostname |
| `vps.passwordSecretFile` | - | Path to age-encrypted password hash |
| `vps.tmpfsSize` | `"512M"` | Root tmpfs size |
| `vps.persistDirs` | `[]` | Extra directories to persist |
| `vps.persistFiles` | `[]` | Extra files to persist |
| `vultr.diskDevice` | `"/dev/vda"` | Primary disk device |
| `vultr.nixPartitionSize` | `"20G"` | /nix partition size |
| `hardening.enableFail2ban` | `true` | Enable fail2ban |
| `hardening.sshPort` | `22` | SSH port |

## Secrets

Create encrypted secrets using the host's public key:

```bash
# Generate keys
mkdir -p secrets
ssh-keygen -t ed25519 -f secrets/deploy-key -N ""
ssh-keygen -t ed25519 -f secrets/host-key -N ""

# Encrypt password hash
mkpasswd -m sha-512 'yourpassword' | age -r "$(cat secrets/host-key.pub)" -o secrets/password-hash.age
```

## Terraform

Use as a module in your project:

```hcl
# terraform/main.tf
terraform {
  required_providers {
    vultr = { source = "vultr/vultr", version = "~> 2.19" }
  }
}

provider "vultr" {}

module "vps" {
  source         = "github.com/brandonros/nix-vps-template//terraform"
  hostname       = "my-vps"
  ssh_public_key = file("${path.root}/../secrets/deploy-key.pub")
  # region       = "atl"
  # plan         = "vc2-2c-4gb"
}

output "server_ipv4" { value = module.vps.server_ipv4 }
```

## Dev Shell

```bash
nix develop  # provides tofu, age, just
```
