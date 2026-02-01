#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  # Pinned to working commit - see https://github.com/elitak/nixos-infect/issues/255
  - curl -L https://raw.githubusercontent.com/elitak/nixos-infect/36f48d8feb89ca508261d7390355144fc0048932/nixos-infect | NIX_CHANNEL=nixos-25.11 bash 2>&1 | tee /var/log/nixos-infect.log
