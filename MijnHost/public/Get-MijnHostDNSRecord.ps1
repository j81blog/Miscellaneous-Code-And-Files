function Get-MijnHostDnsRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $url = "https://mijn.host/api/v2/domains/$DomainName/dns"
    Invoke-MijnHostApi -Method Get -Url $url -ApiKey $ApiKey
}