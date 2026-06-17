terraform {
  required_providers {
    incus = {
      source = "lxc/incus"
    }
  }
}

provider "incus" {}

locals {
  networks = {
    frontendbr0 = { cidr = "10.10.30.1/24" }
    internalbr0 = { cidr = "10.10.60.1/24" }
    publicbr0   = { cidr = "10.10.40.1/24" }
    servicesbr0 = { cidr = "10.10.20.1/24" }
    authbr0     = { cidr = "10.10.50.1/24" }
  }
}

locals {
  frontend_cloud_init = <<EOT
    #cloud-config
    package_update: true
    package_upgrade: true 
    packages:
      - vim
      - curl
      - ufw
      - ssh
    users:
      - name: rogue
        lock_passwd: false
        ssh_pwauth: false
        hashed_passwd: $6$rounds=4096$53/G9n4LfZV70MGb$ii7folbytSgdOOvRG2sTDd4/YUg.9on3Eld14GpwVSNGJFo4RTHz8rp7zUWLHEkjl67Ak/GwMDRThpFHsO3Rp/
        groups: sudo
        shell: /bin/bash
        ssh_authorized_keys:
          - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZMUOw2DT77UbYhUnX8lXE/qua8+Eo0Y6KaFSwrxF0H root@jumpbox
    runcmd:
      - curl -fsSL get.docker.com > docker.sh
      - chmod +x docker.sh
      - ./docker.sh
      - rm docker.sh
      - ufw enable
      - systemctl enable ufw docker
      - curl -fsSL https://tailscale.com/install.sh | sh
      - systemctl enable --now tailscaled ssh
  EOT
}

resource "incus_network_acl" "acls" {
  for_each    = local.networks
  name        = each.key
  description = "ACL for ${each.key}"
  egress = [
    {
      action = "allow"
      state  = "enabled"
    }
  ]
}

resource "incus_network" "bridges" {
  for_each = local.networks
  name     = each.key
  type     = "bridge"
  depends_on = [incus_network_acl.acls] 
  config = {
    "ipv4.address" = each.value.cidr
    "ipv4.nat"     = "true"
    "security.acls"  = each.key
  }
}

resource "incus_profile" "frontends" {
  name = "frontends-01"

  config = {
    "boot.autostart" = true
    "limits.cpu"     = 3
    "limits.memory"  = "16GiB"
    "cloud-init.user-data" = local.frontend_cloud_init
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = incus_network.bridges["frontendbr0"].name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "electron"
      size = "50GiB"
    }
  }
}

resource "incus_profile" "auth" {
  name = "auth-01"

  config = {
    "boot.autostart" = true
    "limits.cpu"     = 1
    "limits.memory"  = "4GiB"
    "cloud-init.user-data" = local.frontend_cloud_init
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = incus_network.bridges["authbr0"].name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "electron"
      size = "50GiB"
    }
  }
}

resource "incus_profile" "services" {
  name = "services-01"

  config = {
    "boot.autostart" = true
    "limits.cpu"     = 4
    "limits.memory"  = "16GiB"
    "cloud-init.user-data" = local.frontend_cloud_init
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = incus_network.bridges["servicesbr0"].name
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "electron"
      size = "100GiB"
    }
  }
}

resource "incus_instance" "frontends" {
  // for_each = toset(["frontends-1", "frontends-2"])
  // name     = each.key
  name     = "frontends-01"
  image    = "images:ubuntu/24.04/cloud"
  type     = "virtual-machine"
  
  profiles = [incus_profile.frontends.name]
  wait_for {
    type = "ipv4"
  }
}

resource "incus_instance" "auth" {
  name     = "auth-01"
  image    = "images:ubuntu/24.04/cloud"
  type     = "virtual-machine"
  
  profiles = [incus_profile.auth.name]
  wait_for {
    type = "ipv4"
  }
}

resource "incus_instance" "services" {
  name     = "services-01"
  image    = "images:ubuntu/24.04/cloud"
  type     = "virtual-machine"
  
  profiles = [incus_profile.services.name]
  wait_for {
    type = "ipv4"
  }
}
