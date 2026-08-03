#!/usr/bin/env just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]

provider := "vultr"
ssh_opts := "-i keys/deploy-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ssh_probe := ssh_opts + " -o ConnectTimeout=5 -o BatchMode=yes"

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
        echo "Created: keys/deploy-key"
    fi

# Get server IP for a deployment
server-ip deployment="default":
    @cd terraform/{{provider}} && tofu workspace select {{deployment}} >/dev/null 2>&1 && tofu output -raw server_ipv4 2>/dev/null

# Deploy infrastructure for a deployment
deploy deployment="default":
    cd terraform/{{provider}} && tofu init -upgrade && tofu workspace select -or-create {{deployment}} && tofu apply -auto-approve

# Wait for NixOS on a deployment
wait deployment="default":
    #!/usr/bin/env bash
    [[ -f keys/deploy-key ]] || { echo "Missing keys/deploy-key - run 'just keygen'"; exit 1; }
    server_ip=$(just provider={{provider}} server-ip {{deployment}})
    [[ -n "$server_ip" ]] || { echo "No server IP - is infrastructure deployed?"; exit 1; }
    echo "Waiting for NixOS on ${server_ip}..."
    while ! ssh {{ssh_probe}} "root@${server_ip}" 'test -e /run/current-system' 2>/dev/null; do
        sleep 5
    done
    echo "NixOS ready"

# SSH into a deployment's server
ssh deployment="default":
    #!/usr/bin/env bash
    [[ -f keys/deploy-key ]] || { echo "Missing keys/deploy-key - run 'just keygen'"; exit 1; }
    server_ip=$(just provider={{provider}} server-ip {{deployment}})
    [[ -n "$server_ip" ]] || { echo "No server IP - is infrastructure deployed?"; exit 1; }
    ssh {{ssh_opts}} "root@${server_ip}"

# Destroy a deployment (resets server.json to placeholder)
destroy deployment="default":
    cd terraform/{{provider}} && tofu init -upgrade && tofu workspace select {{deployment}} && tofu destroy -auto-approve && tofu workspace select default && tofu workspace delete {{deployment}}
    echo '{"ip": "0.0.0.0", "provider": "{{provider}}"}' > deployments/{{deployment}}/server.json

# Rebuild NixOS on a deployment's server
rebuild deployment="default":
    #!/usr/bin/env bash
    [[ -f keys/deploy-key ]] || { echo "Missing keys/deploy-key - run 'just keygen'"; exit 1; }
    server_ip=$(just provider={{provider}} server-ip {{deployment}})
    [[ -n "$server_ip" ]] || { echo "No server IP - is infrastructure deployed?"; exit 1; }
    ssh {{ssh_opts}} "root@${server_ip}" \
        "nixos-rebuild switch --refresh --flake github:brandonros/nix-vps-template#{{deployment}}"

# Full deploy cycle for a deployment
go deployment="default": (deploy deployment) (write-config deployment) (wait deployment) (rebuild deployment)
    @echo "Ready: $(just provider={{provider}} server-ip {{deployment}})"

# Write server.json for a deployment (for local use)
write-config deployment="default":
    #!/usr/bin/env bash
    IP=$(just provider={{provider}} server-ip {{deployment}})
    [[ -n "$IP" ]] || { echo "No server IP - is infrastructure deployed?"; exit 1; }
    mkdir -p deployments/{{deployment}}
    echo "{\"ip\": \"$IP\", \"provider\": \"{{provider}}\"}" > deployments/{{deployment}}/server.json
    echo "Wrote deployments/{{deployment}}/server.json with IP: $IP"
