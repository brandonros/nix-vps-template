# Vultr VPS with pre-built NixOS image

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

variable "plan" {
  type        = string
  default     = "vc2-2c-4gb"
  description = "Vultr plan (vc2-1c-1gb, vc2-2c-4gb, etc.)"
}

variable "region" {
  type        = string
  default     = "atl"
  description = "Vultr region (atl, ewr, lax, etc.)"
}

variable "enable_ipv6" {
  type        = bool
  default     = false
  description = "Enable IPv6 on the instance"
}

variable "nixos_image_url" {
  type        = string
  default     = "https://github.com/brandonros/nix-vps-template/releases/download/base/nixos-base.raw.gz"
  description = "URL to NixOS base image"
}

# Create snapshot from pre-built NixOS image
resource "vultr_snapshot_from_url" "nixos" {
  url = var.nixos_image_url
}

resource "vultr_instance" "server" {
  plan        = var.plan
  region      = var.region
  snapshot_id = vultr_snapshot_from_url.nixos.id
  hostname    = var.hostname
  enable_ipv6 = var.enable_ipv6
}

output "server_id" {
  value = vultr_instance.server.id
}

output "server_ipv4" {
  value = vultr_instance.server.main_ip
}
