#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Generate SSH key (if needed)
keygen:
    #!/usr/bin/env bash
    if [ -f keys/deploy-key ]; then
        echo "Key exists: keys/deploy-key"
    else
        mkdir -p keys
        ssh-keygen -t ed25519 -f keys/deploy-key -N ""
        echo "Created: keys/deploy-key (private, gitignored)"
        echo "Created: keys/deploy-key.pub (public, commit this)"
    fi

# Get server IP
server-ip:
    @cd terraform && tofu output -raw server_ipv4 2>/dev/null

# Deploy infrastructure
deploy:
    cd terraform && tofu init -upgrade && tofu apply

# Wait for NixOS (not just SSH - waits for nixos-infect to complete)
wait:
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    echo "Waiting for NixOS on ${server_ip}..."
    while ! ssh -i keys/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes "root@${server_ip}" 'test -f /etc/NIXOS' 2>/dev/null; do
        sleep 5
    done
    echo "NixOS ready"

# SSH into server
ssh:
    ssh -i keys/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$(just server-ip)"

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
rebuild repo="brandonros/nix-vps-template" flake="default" branch="":
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    branch_part=""
    if [ -n "{{branch}}" ]; then
        branch_part="/{{branch}}"
    fi
    ssh -i keys/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${server_ip}" \
        "nixos-rebuild switch --refresh --flake github:{{repo}}${branch_part}#{{flake}}"

# Dry-run rebuild (build + show what would change, no activation)
rebuild-dry repo="brandonros/nix-vps-template" flake="default" branch="":
    #!/usr/bin/env bash
    server_ip=$(just server-ip)
    branch_part=""
    if [ -n "{{branch}}" ]; then
        branch_part="/{{branch}}"
    fi
    ssh -i keys/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${server_ip}" \
        "nixos-rebuild dry-activate --refresh --flake github:{{repo}}${branch_part}#{{flake}}"
