function Get-MijnHostDomainAuthCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    $url = "https://mijn.host/api/v2/domains/$DomainName/auth-code"
    Invoke-MijnHostApi -Method Get -Url $url -ApiKey $ApiKey
}