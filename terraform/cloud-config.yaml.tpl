#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  # Set filesystem labels dynamically (detect boot/root partitions)
  - |
    # Find and label the EFI/boot partition (vfat)
    boot_dev=$(lsblk -rno NAME,FSTYPE | grep 'vfat' | head -1 | awk '{print $1}')
    if [ -n "$boot_dev" ]; then
      fatlabel "/dev/$boot_dev" NIXBOOT
    fi
    # Find and label the root partition (ext4, largest)
    root_dev=$(lsblk -rno NAME,FSTYPE,MOUNTPOINT | grep 'ext4' | grep '/$' | awk '{print $1}')
    if [ -n "$root_dev" ]; then
      e2label "/dev/$root_dev" NIXROOT
    fi
  # Run nixos-infect
  - |
    curl -L https://github.com/elitak/nixos-infect/raw/master/nixos-infect | NIX_CHANNEL=nixos-25.11 bash -x 2>&1 | tee /var/log/nixos-infect.log
