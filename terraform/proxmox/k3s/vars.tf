variable "proxmox_token" {
  type = string
}

variable "ssh_key" {
  type = string
}

variable "proxmox_hosts" {
  type = list(object({
    name     = string
    endpoint = string
    username = string
    password = string
  }))
}


variable "vm_hostcount" {
  type    = number
  default = 2
}
