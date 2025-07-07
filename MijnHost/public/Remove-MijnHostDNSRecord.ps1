function Remove-MijnHostDNSRecord {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV', 'NS', 'CAA', 'PTR', 'SOA')]
        [string]$Type
    )

    Write-Verbose "Preparing to remove DNS record, searching for record."
    $records = Get-MijnHostDnsRecords -DomainName $DomainName -ApiKey $ApiKey
    $newRecords = [PSCustomObject]@{
        domain  = $DomainName
        records = @()
    }
    Write-Verbose "Filtering DNS records."
    $newRecords.records = $records.records | Where-Object { -Not (($_.name -eq $Name -or $_.name -eq "$($Name).$($DomainName)." ) -and $_.type -ieq $Type) }
    if ($newRecords.records.Count -eq $records.records.Count) {
        Write-Warning "No DNS record found with name '$Name' and type '$Type'."
        return
    } elseif ($newRecords.records.Count -lt $records.records.Count) {
        Write-Verbose "DNS record found, preparing to remove."
        if (-not $PSCmdlet.ShouldProcess("DNS records for domain '$DomainName'", "Remove DNS record '$Name' with type '$Type'")) {
            return
        }
        Write-Verbose "Preparing to remove DNS record."
        $null = Set-MijnHostDnsRecords -ApiKey $ApiKey -Records $newRecords
        Write-Verbose "DNS record removed."
    } else {
        Write-Error "Unexpected error occurred while removing DNS record."
    }
}