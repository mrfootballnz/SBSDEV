param (
    [Parameter(Mandatory=$true)]
    [string]$VmName,

    [Parameter(Mandatory=$true)]
    [string]$localAdmin,

    [Parameter(Mandatory=$true)]
    [string]$password,

    [Parameter(Mandatory=$true)]
    [string]$NetworkConfigurations
)

try {
    #Start-Sleep -Seconds 300

    # Debug: Print the received JSON
    Write-Host "Received NetworkConfigurations: $NetworkConfigurations"

    # Convert JSON input to a PowerShell object
    $networkConfigurations = $NetworkConfigurations | ConvertFrom-Json -ErrorAction Stop

    # Debug: Print the parsed network configurations
    Write-Host "Parsed NetworkConfigurations: $($networkConfigurations | ConvertTo-Json -Depth 3)"

    # Convert plain text password to secure string
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    # Create a PSCredential object
    $cred = New-Object System.Management.Automation.PSCredential($localAdmin, $securePassword)

    # Create a session to the VM using PowerShell Direct
    $session = New-PSSession -VMName $VmName -Credential $cred

    # Wait for the VM to be ready by checking if the "vmicguestinterface" service is running
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
        throw "VM $VmName did not become ready within the expected time."
    }

    # Define the script block to configure the network
    $scriptBlock = {
        param (
            [Parameter(Mandatory=$true)]
            [Object[]]$networkConfigurations
        )
        Write-Host "Received network configurations: $($networkConfigurations | ConvertTo-Json -Depth 3)"

        # Get all active network adapters
        $NetworkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }

        if ($NetworkAdapters) {
            $index = 0
            foreach ($adapter in $NetworkAdapters) {
                if ($index -lt $networkConfigurations.Length) {
                    $config = $networkConfigurations[$index]
                    $index++

                    Write-Host "Configuring network adapter: $($adapter.Name)"
                    Write-Host "IP Address: $($config.IPAddress), Prefix Length: $($config.PrefixLength), Gateway: $($config.Gateway), DNS Servers: $($config.DNSServers -join ', ')"

                    # Remove any existing IP configuration
                    Remove-NetIPAddress -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue
                    Remove-NetRoute -InterfaceAlias $adapter.Name -Confirm:$false -ErrorAction SilentlyContinue

                    # Configure IP address
                    try {
                        New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $config.IPAddress -PrefixLength $config.PrefixLength -DefaultGateway $config.Gateway -ErrorAction Stop
                    } catch {
                        Write-Error "Failed to configure IP address on adapter $($adapter.Name): $_"
                        continue
                    }

                    # Configure DNS servers
                    try {
                        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $config.DNSServers -ErrorAction Stop
                    } catch {
                        Write-Error "Failed to configure DNS servers on adapter $($adapter.Name): $_"
                        continue
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
    Invoke-Command -Session $session -ScriptBlock $scriptBlock -ArgumentList (, $networkConfigurations)

    # Close the session
    Remove-PSSession -Session $session
} catch {
    Write-Error "Script failed: $_"
    throw
}