hyper-v = {
  hyperv_user     = "sbsdev.local\\kain"
  hyperv_password = "9s3ooKcuLVV9rB57F"
  hyperv_host     = "server4.sbsdev.local"     
  port            = 5985
  https           = false
}

local_admin = {
  local_admin = "Administrator"
  password = "spot123!"
}

vm_specs = [
  {
    name                    = "SBSDEV-TESTVM01"
    generation              = 2
    checkpoint_type         = "Production"
    processor_count         = 4
    memory_startup_bytes    = 2 * 1024 * 1024 * 1024   # 2GB in bytes
    memory_maximum_bytes    = 8 * 1024 * 1024 *1024  # 8GB in bytes
    memory_minimum_bytes    = 2 * 1024 * 1024 * 1024   # 2GB in bytes
    dynamic_memory          = true
    path                    = "D:\\Virtual Machines\\SBSDEV-TESTVM01"
    template_vhd_path       = "D:\\Virtual Machines\\VHD-TEMPLATE\\Win2022_DC_GUI.vhdx"
    script_path             = ".\\config_network_multi_adapters.ps1"
    vm_disks                = [
      {
        vhd_size_gb          = 100 * 1024 * 1024 * 1024 # 100GB in byte
        disk_count            = 1
      },
      {
        vhd_size_gb              = 80 * 1024 * 1024 * 1024 # 100GB in byte
        disk_count            = 2
      }
    ]
    
    vm_network_adaptors     = [
      {
        name             = "SBSDEV-TESTVM01-NIC1"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      },
      {
        name             = "SBSDEV-TESTVM01-NIC2"
        switch_name      = "PRODTEAM1"
        #vlan_access      = false
        #vlan_id          = ""
        dynamic_mac_address = false
      }
    ]
  }
]
