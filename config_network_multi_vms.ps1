# Define variables for local admin and password common to all VMs
$localAdmin = "spotadmin"
$password = "spot123!"

# Define variables for multiple VMs
$vms = @(
    @{
        Name = "SBSDEVWEB01"
    },
    @{
        Name = "SBSDEVWEB02"
    }
)

# Define network configurations
$networkConfigurations = @(
    @{
        IPAddress    = "192.168.208.207"
        PrefixLength = 24
        Gateway      = "192.168.208.5"
        DnsServers   = @("192.168.208.11", "192.168.208.12")
    },
    @{
        IPAddress    = "192.168.208.208"
        PrefixLength = 24
        Gateway      = "192.168.208.205"
        DnsServers   = @("192.168.208.11", "192.168.208.12")
    }
)

# Convert plain text password to secure string
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Create a PSCredential object
$cred = New-Object System.Management.Automation.PSCredential($localAdmin, $securePassword)

foreach ($vm in $vms) {
    $vmName = $vm.Name

    # Create a session to the VM using PowerShell Direct
    try {
        $session = New-PSSession -VMName $vmName -Credential $cred -ErrorAction Stop
        Write-Host "Successfully created a session to the VM: $vmName"
    } catch {
        Write-Host "Failed to create a session to the VM: $vmName"
        Write-Host "Error: $_"
        continue
    }

    # Wait for the VM to be ready using PowerShell Direct
    $retries = 30
    $count = 0
    while ($count -lt $retries) {
        try {
            # Check if the "vmicguestinterface" service is running
            $serviceStatus = Invoke-Command -VMName $VmName -Credential $cred -ScriptBlock {
                Get-Service -Name "vmicguestinterface" -ErrorAction Stop
            } -ErrorAction Stop

            if ($serviceStatus.Status -eq "Running") {
                Write-Host "VM $VmName is ready (vmicguestinterface service is running)."
                break
            } else {
                Write-Host "Waiting for VM $VmName to be ready... (Attempt $($count + 1)/$retries)"
                Start-Sleep -Seconds 10
                $count++
            }
        } catch {
            Write-Host "Waiting for VM $VmName to be ready... (Attempt $($count + 1)/$retries)"
            Start-Sleep -Seconds 10
            $count++
        }
    }

    if ($count -eq $retries) {
        Write-Host "VM $vmName did not become ready within the expected time."
        Remove-PSSession -Session $session
        continue
    }

    # Define the script block to configure the network
    $scriptBlock = {
        param (
            [Parameter(Mandatory=$true)]
            [Object[]]$networkConfigurations
        )

        # Function to check if network configuration is already applied
function Is-NetworkConfigApplied {
    param (
        [string]$adapterName,
        [string]$ipAddress,
        [int]$prefixLength,
        [string]$gateway,
        [string[]]$dnsServers
    )

    $currentConfig = Get-NetIPAddress -InterfaceAlias $adapterName | Where-Object { $_.IPAddress -eq $ipAddress -and $_.PrefixLength -eq $prefixLength -and $_.DefaultGateway -eq $gateway }
    $currentDnsServers = (Get-DnsClientServerAddress -InterfaceAlias $adapterName).ServerAddresses

    if ($currentConfig -and $currentDnsServers -eq $dnsServers) {
        return $true
    } else {
        return $false
    }
}

        Write-Host "Received network configurations: $($networkConfigurations | ConvertTo-Json -Depth 3)"
        # Get all active network adapters on the guest VM
        $NetworkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

        if ($NetworkAdapters) {
            $index = 0
            foreach ($adapter in $NetworkAdapters) {
                if ($index -lt $networkConfigurations.Length) {
                    $config = $networkConfigurations[$index]
                    $index++

                    Write-Host "Configuring network adapter: $($adapter.Name)"
                    Write-Host "IP Address: $($config.IPAddress), Prefix Length: $($config.PrefixLength), Gateway: $($config.Gateway), DNS Servers: $($config.DnsServers -join ', ')"

                    # Check if the network configuration is already applied
                    if (-not (Is-NetworkConfigApplied -adapterName $adapter.Name -ipAddress $config.IPAddress -prefixLength $config.PrefixLength -gateway $config.Gateway -dnsServers $config.DnsServers)) {
                        # Remove any existing IP configuration
                        Remove-NetIPAddress -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                        Remove-NetRoute -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue

                        # Configure IP address
                        New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $config.IPAddress -PrefixLength $config.PrefixLength -DefaultGateway $config.Gateway -ErrorAction Stop

                        # Configure DNS servers
                        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $config.DnsServers -ErrorAction Stop
                    } else {
                        Write-Host "Network configuration already applied for adapter: $($adapter.Name)"
                    }
                } else {
                    Write-Host "No more network configurations available for adapter: $($adapter.Name)"
                    break
                }
            }
        } else {
            Write-Host "No active network adapters found on the VM."
        }
    }

    # Run the script block on the VM
    try {
        Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList (, $networkConfigurations) -ErrorAction Stop
        Write-Host "Network configuration script executed successfully on the VM: $vmName"
    } catch {
        Write-Host "Failed to execute the network configuration script on the VM: $vmName"
        Write-Host "Error: $_"
        Remove-PSSession -Session $session
        continue
    }

    # Close the session
    Remove-PSSession -Session $session
    Write-Host "Closed the session to the VM: $vmName"
}