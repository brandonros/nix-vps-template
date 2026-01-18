#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

# Flake target for nixos-anywhere (override in your project)
flake_target := env_var_or_default("FLAKE_TARGET", ".#nixos-vps")

# GitHub repo for remote rebuilds (override in your project)
github_repo := ""

# Default recipe
default:
    @just --list

# === Setup ===

# One-time setup: generate keys and create secrets
init:
    just keygen
    just hostkeygen
    just secrets-init
    @echo ""
    @echo "Setup complete! Run: just go"

# Generate SSH deploy key
keygen:
    #!/usr/bin/env bash
    if [ -f secrets/deploy-key ]; then
        echo "Deploy key already exists"
    else
        mkdir -p secrets
        ssh-keygen -t ed25519 -f secrets/deploy-key -N ""
    fi

# Generate SSH host key (for agenix)
hostkeygen:
    #!/usr/bin/env bash
    if [ -f secrets/host-key ]; then
        echo "Host key already exists"
    else
        mkdir -p secrets
        ssh-keygen -t ed25519 -f secrets/host-key -N "" -C "nixos-vps"
    fi

# Create and encrypt base secrets (override for service-specific secrets)
secrets-init:
    #!/usr/bin/env bash
    mkdir -p secrets
    host_pub=$(cat secrets/host-key.pub)
    if [ ! -f secrets/password-hash.age ]; then
        read -s -p "Enter system password: " password
        echo
        nix-shell -p mkpasswd --run "mkpasswd -m sha-512 '$password'" \
            | age -r "$host_pub" -o secrets/password-hash.age
        echo "Created secrets/password-hash.age"
    fi

# === Infrastructure ===

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

# Bootstrap NixOS (idempotent - skips if already NixOS)
bootstrap:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    if ssh -i secrets/deploy-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 "root@${server_ip}" 'test -f /etc/NIXOS' 2>/dev/null; then
        echo "NixOS already installed, skipping bootstrap"
        exit 0
    fi
    echo "Installing NixOS on ${server_ip}..."
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

# Rebuild from remote flake (requires github_repo to be set)
rebuild:
    #!/usr/bin/env bash
    if [ -z "{{github_repo}}" ]; then
        echo "Error: github_repo not set. Override it in your Justfile."
        exit 1
    fi
    ssh -i secrets/deploy-key -o StrictHostKeyChecking=no "root@$(just server-ip)" \
        "nixos-rebuild switch --refresh --flake github:{{github_repo}}#$(echo {{flake_target}} | sed 's/.*#//')"

# Destroy infrastructure
destroy:
    cd terraform && tofu destroy

# Full deploy
go:
    just deploy
    just wait
    just bootstrap
    @echo "Server ready at $(just server-ip)"

# === CI (non-interactive) ===

# CI deploy
ci-deploy:
    cd terraform && tofu init -upgrade && tofu apply -auto-approve

# CI destroy
ci-destroy:
    cd terraform && tofu destroy -auto-approve

# CI full deploy
ci-go:
    just ci-deploy
    just wait
    just bootstrap
    @echo "Server ready at $(just server-ip)"
