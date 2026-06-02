function Set-MijnHostDnsRecord {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Records
    )

    if (-not $PSCmdlet.ShouldProcess("DNS records for '$DomainName'", 'Overwrite ALL records')) { return }

    $body = [PSCustomObject]@{ records = @($Records) }
    $url  = "https://mijn.host/api/v2/domains/$DomainName/dns"
    Invoke-MijnHostApi -Method Put -Url $url -ApiKey $ApiKey -Body $body
}
