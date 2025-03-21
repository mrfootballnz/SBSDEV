hyper-v = {
  hyperv_user     = "sbsdev.local\\kain"
  hyperv_password = "9s3ooKcuLVV9rB57F"
  hyperv_host     = "Server4.sbsdev.local"     
  port            = 5985
  https           = false
}

local_admin = {
  local_admin = "spotadmin"
  password = "spot123!"
}

script_path       = "C:\\Repository\\SBSDEV\\config_network_multi_vms.ps1"

#template_vhd_path = "D:\\Virtual Machines\\VHD-TEMPLATE\\Win2022_unattend.vhdx"

vm_specs = [
  {
    name                    = "SBSDEVWEB01"
    generation              = 2
    checkpoint_type         = "Production"
    processor_count         = 4
    memory_startup_bytes    = 8 * 1024 * 1024 * 1024   # 8GB in bytes
    memory_maximum_bytes    = 8 * 1024 * 1024 *1024  # 8GB in bytes
    memory_minimum_bytes    = 8 * 1024 * 1024 * 1024   # 8GB in bytes
    dynamic_memory          = true
    path                    = "D:\\Virtual Machines\\SBSDEVWEB01"
    template_vhd_path       = "D:\\Virtual Machines\\VHD-TEMPLATE\\Win2022_DC_Template.vhdx"
    vm_disks                = [
      {
        vhd_size_gb         = 100  # 100GB in GB
      },
      {
        vhd_size_gb         = 80  # 80GB in GB
      }
    ]
    
    vm_network_adaptors     = [
      {
        name             = "SBSDEVWEB01-NIC1"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      },
      {
        name             = "SBSDEVWEB01-NIC2"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      }
    ]
    network_configurations   = [
      {
        IPAddress            = "192.168.208.207"
        PrefixLength         = 24
        Gateway              = "192.168.208.5"
        DNSServers           = ["192.168.208.11", "192.168.208.12"]
      },
      {
        IPAddress            = "192.168.208.208"
        PrefixLength         = 24
        Gateway              = "192.168.208.5"
        DNSServers           = ["192.168.208.11", "192.168.208.12"]
      }
    ]

  },
  {
    name                    = "SBSDEVWEB02"
    generation              = 2
    checkpoint_type         = "Production"
    processor_count         = 4
    memory_startup_bytes    = 8 * 1024 * 1024 * 1024   # 8GB in bytes
    memory_maximum_bytes    = 8 * 1024 * 1024 *1024  # 8GB in bytes
    memory_minimum_bytes    = 8 * 1024 * 1024 * 1024   # 8GB in bytes
    dynamic_memory          = true
    path                    = "D:\\Virtual Machines\\SBSDEVWEB02"
    template_vhd_path       = "D:\\Virtual Machines\\VHD-TEMPLATE\\Win2022_unattend.vhdx"
    vm_disks                = [
      {
        vhd_size_gb         = 100  # 100GB in GB
      },
      {
        vhd_size_gb         = 80  # 80GB in GB
      }
    ]
    
    vm_network_adaptors     = [
      {
        name             = "SBSDEVWEB02-NIC1"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      },
      {
        name             = "SBSDEVWEB02-NIC2"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      }
    ]
    network_configurations   = [
      {
        IPAddress            = "192.168.208.209"
        PrefixLength         = 24
        Gateway              = "192.168.208.5"
        DNSServers           = ["192.168.208.11", "192.168.208.12"]
      },
      {
        IPAddress            = "192.168.208.210"
        PrefixLength         = 24
        Gateway              = "192.168.208.5"
        DNSServers           = ["192.168.208.11", "192.168.208.12"]
      }
    ]

  }
]