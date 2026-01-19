#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  # Set filesystem labels (Vultr Debian layout: vda1=boot, vda2=root)
  - fatlabel /dev/vda1 NIXBOOT
  - e2label /dev/vda2 NIXROOT
  # Run nixos-infect
  - curl -L https://github.com/elitak/nixos-infect/raw/master/nixos-infect | NIX_CHANNEL=nixos-25.11 bash 2>&1 | tee /var/log/nixos-infect.log
