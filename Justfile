#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Generate SSH key (if needed)
keygen:
    #!/usr/bin/env bash
    if [ -f secrets/deploy-key ]; then
        echo "Key exists: secrets/deploy-key"
    else
        mkdir -p secrets assets
        ssh-keygen -t ed25519 -f secrets/deploy-key -N ""
        cp secrets/deploy-key.pub assets/deploy-key.pub
        echo "Public key: assets/deploy-key.pub (commit this)"
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
    while ! ssh -i assets/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes "root@${server_ip}" 'echo ok' 2>/dev/null; do
        sleep 5
    done

# SSH into server
ssh:
    ssh -i assets/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$(just server-ip)"

# Destroy
destroy:
    cd terraform && tofu init -upgrade && tofu destroy

# Full deploy: infra + rebuild
go: deploy wait rebuild
    @echo "Ready: $(just server-ip)"

# CI variants
ci-deploy:
    cd terraform && tofu init -upgrade && tofu apply -auto-approve

ci-destroy:
    cd terraform && tofu init -upgrade && tofu destroy -auto-approve

ci-go: ci-deploy wait rebuild
    @echo "Ready: $(just server-ip)"

# Rebuild NixOS on existing server (fetches flake from GitHub)
# Usage: just rebuild [repo] [flake] [branch]
# Examples:
#   just rebuild                                    # uses defaults
#   just rebuild brandonros/ez3proxy ez3proxy      # switch to ez3proxy
#   just rebuild brandonros/ez3proxy ez3proxy main # with specific branch
rebuild repo="brandonros/nix-vps-template" flake="nixos-vps" branch="":
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    branch_part=""
    if [ -n "{{branch}}" ]; then
        branch_part="/{{branch}}"
    fi
    ssh -i assets/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${server_ip}" \
        "nixos-rebuild switch --refresh --flake github:{{repo}}${branch_part}#{{flake}}"
