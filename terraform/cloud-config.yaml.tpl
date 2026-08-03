#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  # dramforever/nixos-infect@disable-systemd-initrd - scripted initrd is required for lustration on 26.05
  # PROVIDER is set explicitly - upstream autodetection is a no-op (broken -v guard, elitak@d54398b)
  - curl -L https://raw.githubusercontent.com/dramforever/nixos-infect/9607bd36bad2859794163e0b64dc435328bb5441/nixos-infect | PROVIDER=${infect_provider} NIX_CHANNEL=${nix_channel} bash 2>&1 | tee /var/log/nixos-infect.log
