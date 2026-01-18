#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

# Flake target for nixos-anywhere (override in your project)
flake_target := env_var_or_default("FLAKE_TARGET", ".#nixos-vps")

# Default recipe
default:
    @just --list

# Generate SSH deploy key
keygen:
    #!/usr/bin/env bash
    if [ -f secrets/deploy-key ]; then
        echo "Deploy key already exists at secrets/deploy-key"
    else
        mkdir -p secrets
        ssh-keygen -t ed25519 -f secrets/deploy-key -N ""
    fi

# Generate SSH host key (for agenix)
hostkeygen:
    #!/usr/bin/env bash
    if [ -f secrets/host-key ]; then
        echo "Host key already exists at secrets/host-key"
    else
        mkdir -p secrets
        ssh-keygen -t ed25519 -f secrets/host-key -N "" -C "nixos-vps"
    fi

# Get server IP from tofu output
server-ip:
    @cd terraform && tofu output -raw server_ipv4 2>/dev/null

# Deploy infrastructure
deploy:
    cd terraform && tofu init -upgrade && tofu apply

# Wait for SSH
wait:
    #!/usr/bin/env bash
    set +e
    server_ip=$(just server-ip)
    echo "Waiting for SSH on ${server_ip}..."
    while ! ssh -i secrets/deploy-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "root@${server_ip}" 'echo ok' 2>/dev/null; do
        sleep 5
    done
    echo "SSH ready"

# Bootstrap NixOS (destructive - reformats disks)
bootstrap:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    echo "Installing NixOS on ${server_ip}..."
    # Prepare host key for agenix decryption (in /persist for impermanence)
    tmp=$(mktemp -d)
    install -d -m 755 "$tmp/persist/etc/ssh"
    install -m 600 secrets/host-key "$tmp/persist/etc/ssh/ssh_host_ed25519_key"
    install -m 644 secrets/host-key.pub "$tmp/persist/etc/ssh/ssh_host_ed25519_key.pub"
    nix run github:nix-community/nixos-anywhere -- \
        --build-on-remote \
        --flake "{{flake_target}}" \
        --target-host "root@${server_ip}" \
        -i secrets/deploy-key \
        --extra-files "$tmp"
    rm -rf "$tmp"

# SSH into server
ssh:
    #!/usr/bin/env bash
    ssh -i secrets/deploy-key -o StrictHostKeyChecking=no "root@$(just server-ip)"

# Destroy infrastructure
destroy:
    cd terraform && tofu destroy

# Full deploy
go:
    just deploy
    just wait
    just bootstrap
    @echo "Server ready at $(just server-ip)"
