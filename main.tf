terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
  }
}

provider "hyperv" {
  user     = var.hyper-v.hyperv_user
  password = var.hyper-v.hyperv_password
  host     = var.hyper-v.hyperv_host
}

resource "hyperv_vhd" "disks" {
  for_each = { for disk in flatten([
    for vm in var.vm_specs : [
      for disk_idx, disk in vm.vm_disks : {
        vm_name  = vm.name
        disk_idx = disk_idx
        path     = disk_idx == 0 ? "${vm.path}\\${vm.name}-disk-0.vhdx" : "${vm.path}\\${vm.name}-disk-${disk_idx + 1}.vhdx"
        size     = disk.vhd_size_gb * 1024 * 1024 * 1024  # Convert GB to bytes
        source   = disk_idx == 0 ? vm.template_vhd_path : null  # Use source for the first disk (OS disk)
      }
    ]
  ]) : "${disk.vm_name}-${disk.disk_idx}" => disk }

  path     = each.value.path
  size     = each.value.size
  #source   = each.value.source
  vhd_type = "Dynamic"
}

resource "hyperv_machine_instance" "vms" {
  for_each = { for vm in var.vm_specs : vm.name => vm }

  name                 = each.value.name
  generation           = each.value.generation
  memory_startup_bytes = each.value.memory_startup_bytes
  processor_count      = each.value.processor_count
  dynamic_memory       = each.value.dynamic_memory

  # Attach all disks
  dynamic "hard_disk_drives" {
    for_each = { for k, v in hyperv_vhd.disks : k => v if length(regexall(each.value.name, k)) > 0 }
    content {
      controller_type     = "SCSI"
      controller_number   = "0"
      controller_location = tonumber(regex("-(\\d+)$", hard_disk_drives.key)[0])
      path                = hard_disk_drives.value.path
    }
  }

  # Attach network adapters
  dynamic "network_adaptors" {
    for_each = each.value.vm_network_adaptors
    content {
      name                = network_adaptors.value.name
      switch_name         = network_adaptors.value.switch_name
      dynamic_mac_address = network_adaptors.value.dynamic_mac_address
    }
  }

  # Provisioner to configure networking post-provisioning
  /*
  provisioner "local-exec" {
    command = <<EOT
      $vmName = "${each.value.name}"
      $scriptPath = "${each.value.script_path}"
      $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "${var.local_admin.local_admin}", (ConvertTo-SecureString -String "${var.local_admin.password}" -AsPlainText -Force)
      Invoke-Command -ComputerName $vmName -Credential $cred -ScriptBlock {
        param($scriptPath)
        & $scriptPath
      } -ArgumentList $scriptPath
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
  */
}