#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  - |
    curl -L https://github.com/elitak/nixos-infect/raw/master/nixos-infect | NIX_CHANNEL=nixos-25.11 bash -x 2>&1 | tee /var/log/nixos-infect.log
