function Update-MijnHostDnsRecord {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV', 'NS', 'CAA', 'PTR', 'SOA')]
        [string]$Type,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter()]
        [int]$TTL = 900
    )

    # Normalize name to include trailing dot as required by the API
    if (-not $Name.EndsWith('.')) { $Name = "$Name." }

    if (-not $PSCmdlet.ShouldProcess("$Type record '$Name' on '$DomainName'", 'Update DNS record')) { return }

    $body = [PSCustomObject]@{
        record = [PSCustomObject]@{
            type  = $Type
            name  = $Name
            value = $Value
            ttl   = $TTL
        }
    }
    $url = "https://mijn.host/api/v2/domains/$DomainName/dns"
    Write-Verbose "Updating $Type record '$Name' on '$DomainName'."
    Invoke-MijnHostApi -Method Patch -Url $url -ApiKey $ApiKey -Body $body
}
