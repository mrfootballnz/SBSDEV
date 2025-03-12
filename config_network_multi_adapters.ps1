# configure_network_multi_adapters.ps1

# Define network settings for each adapter
$networkConfigurations = @(
    @{
        AdapterName   = "Ethernet"  # Name of the network adapter
        IPAddress     = "192.168.208.207"
        PrefixLength  = 24          # Subnet mask (e.g., 24 for 255.255.255.0)
        Gateway       = "192.168.208.5"
        DnsServers    = @("192.168.208.11", "192.168.208.12")
    },
    @{
        AdapterName   = "Ethernet 2"  # Name of the second network adapter
        IPAddress     = "192.168.208.208"
        PrefixLength  = 24
        Gateway       = "192.168.208.205"
        DnsServers    = @("192.168.208.11", "192.168.208.12")
    }
)

# Iterate through each network configuration
foreach ($config in $networkConfigurations) {
    # Get the network adapter by name
    $adapter = Get-NetAdapter -Name $config.AdapterName -ErrorAction SilentlyContinue

    if ($adapter) {
        Write-Output "Configuring adapter: $($config.AdapterName)"

        # Remove existing IP configuration
        Remove-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceIndex $adapter.InterfaceIndex -Confirm:$false -ErrorAction SilentlyContinue

        # Set static IP and gateway
        New-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex `
                         -IPAddress $config.IPAddress `
                         -PrefixLength $config.PrefixLength `
                         -DefaultGateway $config.Gateway `
                         -ErrorAction Stop

        # Set DNS servers
        Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
                                   -ServerAddresses $config.DnsServers `
                                   -ErrorAction Stop

        Write-Output "Successfully configured adapter: $($config.AdapterName)"
    } else {
        Write-Output "Adapter not found: $($config.AdapterName)"
    }
}
# Set up openssh and python

# Optional: Disable the DVD drive after configuration
Set-VMDvdDrive -VMName $env:COMPUTERNAME -Path $null