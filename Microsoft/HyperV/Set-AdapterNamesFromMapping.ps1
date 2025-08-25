<#
.SYNOPSIS
    Renames network adapters on a server based on a provided mapping file (CSV/JSON).
.DESCRIPTION
    This script reads a mapping of logical names to MAC addresses and renames the
    local network adapters accordingly. This ensures consistent naming across servers
    before applying further configuration.
.PARAMETER MappingFile
    The full path to the CSV or JSON file containing the adapter mappings.
    The file must contain 'LogicalName' and 'MacAddress' columns/properties.
.EXAMPLE
    Set-AdapterNamesFromMapping -MappingFile C:\Temp\Server01-mappings.csv

.EXAMPLE
    @"
    LogicalName,MacAddress
    MGMT-01,00-15-5D-01-0A-01
    MGMT-02,00-15-5D-01-0A-02
    ISCSI-01,00-15-5D-01-0A-03
    ISCSI-02,00-15-5D-01-0A-04
    LAN-01,00-15-5D-01-0A-05
    LAN-02,00-15-5D-01-0A-06
    "@ | Set-Content -Path C:\Temp\Server01-mappings.csv
    Set-AdapterNamesFromMapping -MappingFile C:\Temp\Server01-mappings.csv
.NOTES
    Version      : 1.1
    Author       : John Billekens Consultancy
    Co-Author    : Gemini (Documentation and review)
    CreationDate : 2025-08-18
#>
function Set-AdapterNamesFromMapping {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$MappingFile
    )

    try {
        $Mappings = $null
        $FileExtension = [System.IO.Path]::GetExtension($MappingFile)

        switch ($FileExtension) {
            '.csv' { $Mappings = Import-Csv -Path $MappingFile }
            '.json' { $Mappings = Get-Content -Path $MappingFile | ConvertFrom-Json }
            default { throw "Unsupported file type: '$FileExtension'. Please use .csv or .json." }
        }

        Write-Host "Processing $($Mappings.Count) mappings from '$($MappingFile)'..." -ForegroundColor Green

        if ($Mappings | Get-Member -Name Hostname -ErrorAction SilentlyContinue) {
            $Mappings = $Mappings | Where-Object { $_.Hostname -eq $env:COMPUTERNAME }
        }

        foreach ($Entry in $Mappings) {
            $LogicalName = $Entry.LogicalName
            $MacAddress = $Entry.MacAddress

            Write-Host "Searching for adapter with MAC Address: $MacAddress" -ForegroundColor White

            # Normalize MAC address format for comparison
            $FormattedMacAddress = $MacAddress -replace '[:-]'
            $Adapter = Get-NetAdapter | Where-Object { ($_.MacAddress -replace '[:-]') -eq $FormattedMacAddress }

            if ($Adapter) {
                Write-Host " -> Found: '$($Adapter.Name)'. Renaming to '$($LogicalName)'." -ForegroundColor Cyan
                Rename-NetAdapter -Name $Adapter.Name -NewName $LogicalName
            } else {
                Write-Warning " -> No adapter found with MAC Address '$MacAddress' on this server."
            }
        }

        Write-Host "`nAdapter renaming process complete." -ForegroundColor Green
    } catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
}

# Example of how to run the function:
$MappingFile = "$PSScriptRoot\$($MyInvocation.MyCommand.Name.Replace('.ps1', '.csv'))"
if (Test-Path -Path $MappingFile) {
    Write-Host "Using mapping file: $MappingFile" -ForegroundColor Cyan
    Set-AdapterNamesFromMapping -MappingFile $MappingFile
} else {
    Write-Host "Mapping file not found: $MappingFile. Please ensure the file exists." -ForegroundColor Red
    return
}
