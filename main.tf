terraform {
  required_providers {
    hyperv = {
      source  = "taliesins/hyperv"
      version = "1.2.1"
    }
    null = {
      # source is required for providers in other namespaces, to avoid ambiguity.
      source  = "hashicorp/null"
      version = "~> 3.1.0"
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
        path     = "${vm.path}\\${vm.name}-disk-${disk_idx}.vhdx"  # Fixed: No +1 increment
        size     = disk.vhd_size_gb * 1024 * 1024 * 1024  # Convert GB to bytes
        source   = disk_idx == 0 ? vm.template_vhd_path : null  # Use source for the first disk (OS disk)
      }
    ]
  ]) : "${disk.vm_name}-${disk.disk_idx}" => disk }

  path     = each.value.path
  size     = each.value.size
  source   = each.value.disk_idx == 0 ? each.value.source : null  # Use source for the first disk (OS disk)
  vhd_type = each.value.disk_idx == 0 ? null : "Dynamic"  # Only set vhd_type for additional disks
  
  lifecycle {
    ignore_changes = [
      path,
      size,
      source
    ]
  }
  
}

resource "hyperv_machine_instance" "vms" {
  for_each = { for vm in var.vm_specs : vm.name => vm }

  name                 = each.value.name
  generation           = each.value.generation
  memory_startup_bytes = each.value.memory_startup_bytes
  processor_count      = each.value.processor_count
  dynamic_memory       = each.value.dynamic_memory
  path                 = each.value.path

  # Configure firmware
  vm_firmware {
    boot_order {
      boot_type = "HardDiskDrive"
      controller_number   = "0"
      controller_location = "0"
    }
  }

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
  # Configure integration services
  integration_services = {
    "Guest Service Interface" = true
    "Heartbeat"               = true
    "Key-Value Pair Exchange" = true
    "Shutdown"                = true
    "Time Synchronization"    = true
    "VSS"                     = true
  }
  /*
  lifecycle {
    ignore_changes = [hyperv_machine_instance.vms]
  }
  */
  # Provisioner to configure networking post-provisioning
  /*
  provisioner "local-exec" {
    command = <<-EOT
      $vmName = "${each.value.name}"
      $scriptPath = "${each.value.script_path}"
      $cred = New-Object System.Management.Automation.PSCredential (
        "${var.local_admin.local_admin}",
        (ConvertTo-SecureString "${var.local_admin.password}" -AsPlainText -Force)
      )
      Invoke-Command -VMName $vmName -Credential $cred -ScriptBlock {
        param($scriptPath)
        & $scriptPath
      } -ArgumentList $scriptPath
    EOT

    interpreter = ["pwsh", "-Command"]
  }
  */
  /*
  provisioner "file" {
   source      = "C:\\Repository\\SBSDEV\\config_network_multi_adapters.ps1"  # Local script path
   destination = "$env:TEMP\\config_network_multi_adapters.ps1"  # Temporary destination in TEMP 
 }
*/
/*
  provisioner "remote-exec" {
    inline = [
      # Write the base64-encoded content to a temporary file
      "Set-Content -Path $env:TEMP\\config_network_multi_adapters.base64.txt -Value @'\n${filebase64("C:\\Repository\\SBSDEV\\config_network_multi_adapters.base64.txt")}\n'@",

      # Decode the base64 content and write it to the destination file
      "$decodedContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-Content -Path $env:TEMP\\config_network_multi_adapters.base64.txt -Raw))); Set-Content -Path C:\\config_network_multi_adapters.ps1 -Value $decodedContent",

      # Execute the script with ExecutionPolicy Bypass
      "powershell -ExecutionPolicy Bypass -File C:\\config_network_multi_adapters.ps1"
    ]

    connection {
      type     = "winrm"
      host     = each.value.name  # Use the VM name as the host
      user     = var.local_admin.local_admin
      password = var.local_admin.password
      https    = false
      port     = 5985
      insecure = true  # Uncomment only if using a self-signed certificate
    }
  }
*/
}

resource "null_resource" "setup_network" {
  #for_each = { for vm in var.vm_specs : vm.name => vm }

  depends_on = [hyperv_machine_instance.vms]

  provisioner "local-exec" {
  command     = "pwsh -ExecutionPolicy Bypass -File C:\\Repository\\SBSDEV\\config_network_multi_vms.ps1"
  interpreter = ["pwsh", "-Command"]
}
}
