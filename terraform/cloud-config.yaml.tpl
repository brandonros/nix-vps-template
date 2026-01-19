#cloud-config

# Set up SSH key so nixos-infect detects it
users:
  - name: root
    ssh_authorized_keys:
      - ${ssh_pubkey}

runcmd:
  # Set filesystem labels dynamically (detect boot/root partitions)
  - |
    exec &> >(tee -a /var/log/cloud-config-labels.log)
    set -x
    echo "=== Setting filesystem labels $(date) ==="
    echo "--- lsblk before labeling ---"
    lsblk -f

    # Find and label the EFI/boot partition (vfat)
    boot_dev=$(lsblk -rno NAME,FSTYPE | grep 'vfat' | head -1 | awk '{print $1}')
    echo "Detected boot device: '$boot_dev'"
    if [ -n "$boot_dev" ]; then
      echo "Labeling /dev/$boot_dev as NIXBOOT"
      fatlabel "/dev/$boot_dev" NIXBOOT && echo "SUCCESS: boot label set" || echo "FAILED: boot label"
    else
      echo "WARNING: No vfat partition found for boot"
    fi

    # Find and label the root partition (ext4 mounted at /)
    root_dev=$(lsblk -rno NAME,FSTYPE,MOUNTPOINT | grep 'ext4' | grep '/$' | awk '{print $1}')
    echo "Detected root device: '$root_dev'"
    if [ -n "$root_dev" ]; then
      echo "Labeling /dev/$root_dev as NIXROOT"
      e2label "/dev/$root_dev" NIXROOT && echo "SUCCESS: root label set" || echo "FAILED: root label"
    else
      echo "WARNING: No ext4 partition mounted at / found"
    fi

    echo "--- lsblk after labeling ---"
    lsblk -f
    echo "=== Done ==="
  # Run nixos-infect
  - |
    curl -L https://github.com/elitak/nixos-infect/raw/master/nixos-infect | NIX_CHANNEL=nixos-25.11 bash -x 2>&1 | tee /var/log/nixos-infect.log
