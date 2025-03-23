#Variable hyper-v object
variable "hyper-v" {
  type = object({
    hyperv_user      = string
    hyperv_password  = string
    hyperv_host      = string
    port             = number
    https            = bool
  })
}

variable "local_admin" {
  type = object({
    local_admin = string
    password = string
  })
}

variable "script_path" {
  type = string
}
/*
variable "template_vhd_path" {
  type = string
}
*/

#variable vm_specs list of objects
variable "vm_specs" {
  description = "VM object specifications"
  type = list(object({
    name                     = string
    generation               = number
    checkpoint_type          = string
    processor_count          = number
    memory_startup_bytes     = number
    memory_maximum_bytes     = number
    memory_minimum_bytes     = number
    dynamic_memory           = bool
    path                     = string
    template_vhd_path        = string
    vm_disks                 = list(object({
      vhd_size_gb            = number    #in gb
    }))
    vm_network_adaptors      = list(object({
        name                 = string
        switch_name          = string
        #vlan_access          = bool
        #vlan_id              = number
        dynamic_mac_address  = bool
    }))
  }))
}