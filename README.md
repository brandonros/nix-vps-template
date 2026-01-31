# nix-vps-template

NixOS VPS deployments monorepo with Vultr infrastructure.

## Deployments

| Name | Description |
|------|-------------|
| `default` | Minimal NixOS VPS |
| `ez3proxy` | 3proxy HTTP/SOCKS5 over OpenVPN |
| `nixginx` | nginx with Let's Encrypt IP certificate |

## Quick Start

```bash
nix develop
just keygen              # generate SSH key (one-time)
just go nixginx          # deploy nixginx (infra + wait + rebuild)
just ssh nixginx         # connect
just destroy nixginx     # tear down
```

## Commands

```bash
just deploy <name>       # provision VM for deployment
just wait <name>         # wait for NixOS to be ready
just rebuild <name>      # apply NixOS configuration
just ssh <name>          # SSH into deployment
just destroy <name>      # destroy deployment
just go <name>           # full cycle: deploy + wait + rebuild
just write-config <name> # write server.json locally
```

## GitHub Actions

Trigger workflows manually with deployment selector:

- **Deploy** → creates VM, writes `server.json`, applies config
- **Destroy** → tears down VM

Each deployment uses its own Terraform workspace for isolated state.

## Adding a New Deployment

1. Create `deployments/<name>/default.nix`:

```nix
{ lib, ... }:
let
  server = builtins.fromJSON (builtins.readFile ./server.json);
in {
  vps.sshPubKey = builtins.readFile ../../keys/deploy-key.pub;
  vps.hostname = "<name>";

  # Your configuration here
}
```

2. Create `deployments/<name>/server.json`:

```json
{"ip": "0.0.0.0"}
```

3. Add to `flake.nix`:

```nix
nixosConfigurations = {
  # ...existing...
  <name> = mkDeployment "<name>";
};
```

4. Add to workflow dropdowns in `.github/workflows/deploy.yaml` and `destroy.yaml`.

## External Usage

The base module can still be consumed by external repos:

```nix
{
  inputs.nix-vps-template.url = "github:brandonros/nix-vps-template";

  outputs = { nixpkgs, nix-vps-template, ... }: {
    nixosConfigurations.my-vps = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-vps-template.nixosModules.default
        {
          vps.sshPubKey = builtins.readFile ./keys/deploy-key.pub;
          vps.hostname = "my-vps";
        }
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

## Requirements

- Nix with flakes enabled
- `VULTR_API_KEY` environment variable
- `TF_VAR_encryption_passphrase` for state encryption
