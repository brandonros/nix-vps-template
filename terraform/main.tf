# Vultr VPS with nixos-infect

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

variable "os_id" {
  type        = number
  default     = 2136
  description = "Vultr OS ID (2136 = Debian 12 Bookworm)"
}

variable "ssh_pubkey" {
  type        = string
  default     = ""
  description = "SSH public key (defaults to keys/deploy-key.pub)"
}

locals {
  ssh_pubkey = var.ssh_pubkey != "" ? var.ssh_pubkey : trimspace(file("${path.module}/../keys/deploy-key.pub"))
}

resource "vultr_instance" "server" {
  plan        = var.plan
  region      = var.region
  os_id       = var.os_id
  hostname    = var.hostname
  enable_ipv6 = var.enable_ipv6
  user_data = templatefile("${path.module}/cloud-config.yaml.tpl", {
    ssh_pubkey = local.ssh_pubkey
  })
}

output "server_id" {
  value = vultr_instance.server.id
}

output "server_ipv4" {
  value = vultr_instance.server.main_ip
}
