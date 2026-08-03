# Hetzner VPS with nixos-infect

terraform {
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.encryption_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method = method.aes_gcm.main
    }
    plan {
      method = method.aes_gcm.main
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60"
    }
  }
}

provider "hcloud" {
  # HCLOUD_TOKEN comes from env var
}

variable "encryption_passphrase" {
  type        = string
  sensitive   = true
  description = "Passphrase for encrypting state and plan files"
}

variable "hostname" {
  type        = string
  default     = "nixos-vps"
  description = "Instance hostname"
}

variable "datacenter" {
  type        = string
  default     = "ash-dc1"
  description = "Hetzner datacenter (ash-dc1, hel1-dc2, fsn1-dc14, etc.)"
}

variable "server_type" {
  type        = string
  default     = "cpx11"
  description = "Hetzner server type (cpx11, cpx21, cpx31, cax11, etc.)"
}

variable "enable_ipv6" {
  type        = bool
  default     = false
  description = "Enable IPv6 on the instance"
}

variable "image" {
  type        = string
  default     = "debian-12"
  description = "Hetzner OS image (debian-12, debian-13, etc.)"
}

variable "ssh_pubkey" {
  type        = string
  default     = ""
  description = "SSH public key (defaults to keys/deploy-key.pub)"
}

variable "nix_channel" {
  type        = string
  default     = "nixos-26.05"
  description = "NixOS channel nixos-infect installs (should match flake.nix nixpkgs)"
}

locals {
  ssh_pubkey = var.ssh_pubkey != "" ? var.ssh_pubkey : trimspace(file("${path.module}/../../keys/deploy-key.pub"))
}

resource "hcloud_server" "server" {
  name        = var.hostname
  image       = var.image
  datacenter  = var.datacenter
  server_type = var.server_type
  public_net {
    ipv4_enabled = true
    ipv6_enabled = var.enable_ipv6
  }
  user_data = templatefile("${path.module}/../cloud-config.yaml.tpl", {
    ssh_pubkey      = local.ssh_pubkey
    nix_channel     = var.nix_channel
    infect_provider = "hetznercloud"
  })
}

output "server_id" {
  value = hcloud_server.server.id
}

output "server_ipv4" {
  value = hcloud_server.server.ipv4_address
}
