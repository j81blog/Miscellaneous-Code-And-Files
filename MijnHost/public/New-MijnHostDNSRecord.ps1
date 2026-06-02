function New-MijnHostDnsRecord {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV', 'NS', 'CAA', 'PTR', 'SOA')]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter()]
        [int]$TTL = 900,

        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    # Normalize name to include trailing dot as required by the API
    if (-not $Name.EndsWith('.')) { $Name = "$Name." }

    $current = Get-MijnHostDnsRecord -DomainName $DomainName -ApiKey $ApiKey

    $newRecord = [PSCustomObject]@{
        type  = $Type
        name  = $Name
        value = $Value
        ttl   = $TTL
    }

    # Check if this exact record already exists
    $exists = $current.records | Where-Object {
        $_.type -eq $Type -and $_.name -eq $Name -and $_.value -eq $Value
    }
    if ($exists) {
        Write-Verbose "Record '$Name' ($Type) with value '$Value' already exists on '$DomainName'. Nothing to do."
        return
    }

    $updatedRecords = [PSCustomObject]@{
        records = @($current.records) + $newRecord
    }

    if (-not $PSCmdlet.ShouldProcess("DNS records for '$DomainName'", "Add $Type record '$Name'")) { return }

    $url = "https://mijn.host/api/v2/domains/$DomainName/dns"
    Invoke-MijnHostApi -Method Put -Url $url -ApiKey $ApiKey -Body $updatedRecords
}
