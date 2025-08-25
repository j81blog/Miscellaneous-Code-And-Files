<#
.SYNOPSIS
    Configures network adapter IP and DNS settings based on a CSV file.

.DESCRIPTION
    This function reads a specified CSV file to configure the IPv4 address, prefix length,
    and DNS server addresses for network adapters on the local machine. It filters the CSV
    data based on the local computer's hostname to apply only the relevant configurations.
    If the IPv4Address field is empty for an entry, the adapter will be configured to use DHCP.

.PARAMETER CsvFile
    Specifies the full path to the CSV input file.
    The CSV file must contain the following headers:
    "Hostname", "InterfaceAlias", "IPv4Address", "PrefixLength", "DNSServerPrimary", "DNSServerSecondary".

.EXAMPLE
    PS C:\> Set-IpConfigurationFromCsv -CsvFile "C:\Temp\NetworkConfig.csv"

    This command reads the network configuration from "C:\Temp\NetworkConfig.csv" and applies
    the settings for the adapters matching the current server's hostname.

.NOTES
    Version:      1.2
    Author:       John Billekens Consultancy
    Co-Author:    Gemini
    CreationDate: 2025-08-22
    Requires:     Windows PowerShell 5.1 or newer.
                  Run with elevated (Administrator) privileges.
#>
function Set-IpConfigurationFromCsv {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "File not found at path: $_"
            }
            return $true
        })]
        [string]$CsvFile
    )

    try {
        Write-Host "Importing network configuration from '$($CsvFile)'..." -ForegroundColor White
        $NicDetails = Import-Csv -Path $CsvFile

        $LocalNicDetails = $NicDetails | Where-Object { $_.Hostname -eq $env:COMPUTERNAME }

        if (-not $LocalNicDetails) {
            Write-Warning "No configuration entries found for hostname '$($env:COMPUTERNAME)' in the specified file."
            return
        }

        ForEach ($Nic in $LocalNicDetails) {
            # Assign variables for clarity
            $InterfaceAlias = $Nic.InterfaceAlias

            # Verify that the network adapter exists before attempting configuration
            $Adapter = Get-NetAdapter -Name $InterfaceAlias -ErrorAction SilentlyContinue
            if (-not $Adapter) {
                Write-Warning "Network adapter with alias '$($InterfaceAlias)' not found on this server. Skipping configuration."
                continue # Skip to the next NIC in the CSV
            }

            $IPv4Address = $Nic.IPv4Address

            # --- IP Configuration Logic ---
            if ([string]::IsNullOrWhiteSpace($IPv4Address)) {
                # DHCP Configuration: No IP address is specified in the CSV.
                Write-Host "Setting '$($InterfaceAlias)' to use DHCP..." -ForegroundColor Cyan

                # Remove any existing static IP addresses from this interface for a clean state.
                Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false

                # Enable DHCP on the interface.
                Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Enabled -AddressFamily IPv4 -ErrorAction Stop

                # Set DNS to be obtained via DHCP as well.
                Write-Host "Setting DNS for '$($InterfaceAlias)' to be obtained via DHCP." -ForegroundColor Cyan
                Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction Stop
            }
            else {
                # Static IP Configuration: An IP address is specified in the CSV.
                $PrefixLength = $Nic.PrefixLength
                $DNSServerPrimary = $Nic.DNSServerPrimary
                $DNSServerSecondary = $Nic.DNSServerSecondary

                Write-Host "Configuring '$($InterfaceAlias)' with static IP $($IPv4Address)/$($PrefixLength)..." -ForegroundColor Cyan

                # Ensure a clean state by removing existing IPs and disabling DHCP.
                Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false
                Set-NetIPInterface -InterfaceAlias $InterfaceAlias -Dhcp Disabled -AddressFamily IPv4 -ErrorAction Stop

                # Set the new static IP Address.
                New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPv4Address -PrefixLength $PrefixLength -ErrorAction Stop

                # Configure DNS Servers.
                if ($DNSServerPrimary -AND $DNSServerSecondary) {
                    $DnsServers = $DNSServerPrimary, $DNSServerSecondary
                    Write-Host "Setting DNS servers for '$($InterfaceAlias)' to $($DnsServers -join ', ')" -ForegroundColor Cyan
                    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DnsServers -ErrorAction Stop
                }
                elseif ($DNSServerPrimary) {
                    Write-Host "Setting DNS server for '$($InterfaceAlias)' to $($DNSServerPrimary)" -ForegroundColor Cyan
                    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServerPrimary -ErrorAction Stop
                }
                else {
                    Write-Host "Resetting DNS servers for '$($InterfaceAlias)' to default (DHCP)." -ForegroundColor Cyan
                    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses -ErrorAction Stop
                }
            }
            Write-Host "Configuration for '$($InterfaceAlias)' completed." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "An error occurred during network configuration: $($_.Exception.Message)"
    }
}

# --- Example on how to use the function ---
# 1. Save the function above in your script or profile.
# 2. Create your CSV file (e.g., C:\Config\NICs.csv).
# 3. Call the function with the path to your file:
#
# Set-IpConfigurationFromCsv -CsvFile "C:\Config\NICs.csv"
