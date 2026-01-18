#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

flake_target := env_var_or_default("FLAKE_TARGET", ".#nixos-vps")

default:
    @just --list

# Generate SSH key (if needed)
keygen:
    #!/usr/bin/env bash
    if [ -f secrets/deploy-key ]; then
        echo "Key exists: secrets/deploy-key"
    else
        mkdir -p secrets
        ssh-keygen -t ed25519 -f secrets/deploy-key -N ""
    fi

# Get server IP
server-ip:
    @cd terraform && tofu output -raw server_ipv4 2>/dev/null

# Deploy infrastructure
deploy:
    cd terraform && tofu init -upgrade && tofu apply

# Wait for SSH
wait:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    echo "Waiting for SSH on ${server_ip}..."
    while ! ssh -i secrets/deploy-key -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "root@${server_ip}" 'echo ok' 2>/dev/null; do
        sleep 5
    done

# Install NixOS
bootstrap:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    if ssh -i secrets/deploy-key -o StrictHostKeyChecking=no "root@${server_ip}" 'test -f /etc/NIXOS' 2>/dev/null; then
        echo "Already NixOS"
        exit 0
    fi
    export SSH_PUBLIC_KEY="$(cat secrets/deploy-key.pub)"
    nix run --impure github:nix-community/nixos-anywhere -- \
        --build-on-remote \
        --flake "{{flake_target}}" \
        --target-host "root@${server_ip}" \
        -i secrets/deploy-key

# SSH into server
ssh:
    ssh -i secrets/deploy-key -o StrictHostKeyChecking=no "root@$(just server-ip)"

# Destroy
destroy:
    cd terraform && tofu destroy

# Full deploy: infra + NixOS
go: deploy wait bootstrap rebuild
    @echo "Ready: $(just server-ip)"

# CI variants
ci-deploy:
    cd terraform && tofu init -upgrade && tofu apply -auto-approve

ci-destroy:
    cd terraform && tofu destroy -auto-approve

ci-go: ci-deploy wait bootstrap rebuild
    @echo "Ready: $(just server-ip)"

# Rebuild NixOS on existing server
rebuild:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    export SSH_PUBLIC_KEY="$(cat secrets/deploy-key.pub)"
    NIX_SSHOPTS="-i secrets/deploy-key -o StrictHostKeyChecking=no" \
    nix run nixpkgs#nixos-rebuild -- switch --flake "{{flake_target}}" --impure \
        --target-host "root@${server_ip}" --build-host "root@${server_ip}"
