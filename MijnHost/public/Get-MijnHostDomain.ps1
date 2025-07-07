function Get-MijnHostDomain {
    [CmdletBinding(DefaultParameterSetName = 'DomainName')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'DomainName')]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory, ParameterSetName = 'DomainName')]
        [Parameter(Mandatory, ParameterSetName = 'All')]
        [string]$ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [string[]]$Tags,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [Switch]$All
    )

    if ($PSBoundParameters.ContainsKey('All')) {
        $url = "https://mijn.host/api/v2/domains"
        if ($Tags) {
            $url += "?tags=$($Tags -join ',')"
        }
        Invoke-MijnHostApi -Method Get -Url $url -ApiKey $ApiKey
        return
    }
    if ($PSBoundParameters.ContainsKey('DomainName')) {
        $url = "https://mijn.host/api/v2/domains/$DomainName"
        Invoke-MijnHostApi -Method Get -Url $url -ApiKey $ApiKey
        return
    }
}