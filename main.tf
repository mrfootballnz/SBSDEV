terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1" # Use the latest version available
    }

  }
}

provider "hyperv" {
  user     = var.hyper-v.hyperv_user
  password = var.hyper-v.hyperv_password
  host     = var.hyper-v.hyperv_host
  port =  var.hyper-v.port
  https = var.hyper-v.https
}

# Create additional VHDs for application/data disks
resource "hyperv_vhd" "vm_vhd" {
  for_each = { for disk in flatten([
    for vm in var.vm_specs : [
      for disk_idx, disk in vm.vm_disks : {
        vm_name  = vm.name
        disk_idx = disk_idx
        path     = "${vm.path}\\${vm.name}-disk-${disk_idx}.vhdx"
        size     = disk.vhd_size_gb
      }
    ]
  ]) : "${disk.vm_name}-${disk.disk_idx}" => disk }

  path = each.value.path
  size = each.value.size
}

resource "hyperv_machine_instance" "vms" {
  count = length(var.vm_specs)

  name                 = var.vm_specs[count.index].name
  generation           = var.vm_specs[count.index].generation
  checkpoint_type      = var.vm_specs[count.index].checkpoint_type
  processor_count      = var.vm_specs[count.index].processor_count
  memory_startup_bytes = var.vm_specs[count.index].memory_startup_bytes
  memory_maximum_bytes = var.vm_specs[count.index].memory_maximum_bytes
  memory_minimum_bytes = var.vm_specs[count.index].memory_minimum_bytes
  dynamic_memory       = var.vm_specs[count.index].dynamic_memory

 vm_firmware {
   boot_order {
     boot_type = "HardDiskDrive"
     controller_number   = "0"
     controller_location = "0"
   }
 }

  dynamic "network_adaptors" {
    for_each = var.vm_specs[count.index].vm_network_adaptors
    content {
      name                 = network_adaptors.value.name
      switch_name          = network_adaptors.value.switch_name
      #vlan_access          = network_adaptors.value.vlan_access
      #vlan_id              = network_adaptors.value.vlan_id
      dynamic_mac_address  = network_adaptors.value.dynamic_mac_address
    }
  }


  # Pass a PowerShell script to configure network settings
  /*
  dvd_drives {
    controller_number = "0"
    controller_location = "1"
    path = var.vm_specs[count.index].script_path
  }
  */

  # Attach the existing Windows Server 2022 template VHD as the OS disk (C:)
  hard_disk_drives {
    controller_type     = "SCSI" # or "IDE" for Generation 1 VMs
    controller_number   = "0"
    controller_location = "0"
    path                = var.vm_specs[count.index].template_vhd_path # Path to the existing OS VHD
    
  }

  # Attach additional VHDs for application/data disks (D:, E:, etc.)
  dynamic "hard_disk_drives" {
    for_each = { for k, v in hyperv_vhd.vm_vhd : k => v if split("-", k)[0] == var.vm_specs[count.index].name }
    content {
      controller_type     = "SCSI"
      controller_number   = "0"
      controller_location = hard_disk_drives.key + 1 # Increment location for additional disks
      path                = hard_disk_drives.value.path
    }
  }

provisioner "local-exec" {
  command = <<EOT
    $vmName = "${var.vm_specs[count.index].name}"
    $username = "${var.local_admin.local_admin}"
    $password = "${var.local_admin.password}"
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($username, $securePassword)
    $scriptPath = "${var.vm_specs[count.index].script_path}"

    # Create a session to the VM using PowerShell Direct
    $session = New-PSSession -VMName $vmName -Credential $cred

    # Define the script block to execute the script
    $scriptBlock = {
        param($scriptPath)
        & $scriptPath
    }

    # Run the script block on the VM
    Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList $scriptPath

    # Close the session
    Remove-PSSession -Session $session
  EOT
  interpreter = ["PowerShell", "-Command"]
}
}

