terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
    }
  }
}

provider "proxmox" {
  alias     = "by_name"
  for_each = {
    for h in var.proxmox_hosts : h.name => h
  }

  endpoint = each.value.endpoint
  username = each.value.username
  password = each.value.password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "k3s_worker" {
  count     = length(var.proxmox_hosts) * var.vm_hostcount  
  provider  = proxmox.by_name[var.proxmox_hosts[floor(count.index / var.vm_hostcount)].name]

  name      = format("worker-%02d", count.index + 1)
  node_name = var.proxmox_hosts[floor(count.index / var.vm_hostcount)].name

  vm_id     = 120 + count.index

  description = "k3s worker 01"
  tags = ["k3s"]

  agent {
    enabled = true
  }

  started = true

  cpu {
    cores = 2
    type = "x86-64-v2-AES"
    architecture = "x86_64"
  }

  memory {
    dedicated = 4096
  }

  clone {
    full = true
    vm_id = 1000
    node_name = var.proxmox_hosts[floor(count.index / var.vm_hostcount)].name
  }

  disk {
     datastore_id = "local-lvm"
     size         = "22"
     interface    = "scsi0"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  stop_on_destroy = true
}
