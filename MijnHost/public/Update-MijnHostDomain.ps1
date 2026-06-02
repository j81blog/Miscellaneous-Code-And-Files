function Update-MijnHostDomain {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey,

        [Parameter()]
        [string]$Nameserver,

        [Parameter()]
        [hashtable]$Dnssec,

        [Parameter()]
        [hashtable]$Profile,

        [Parameter()]
        [bool]$IsLocked,

        [Parameter()]
        [hashtable]$Forwarder,

        [Parameter()]
        [string[]]$Tags
    )

    if (-not $PSCmdlet.ShouldProcess("Domain '$DomainName'", 'Update domain settings')) { return }

    $bodyHash = [ordered]@{}
    if ($PSBoundParameters.ContainsKey('Nameserver')) { $bodyHash.nameserver = $Nameserver }
    if ($PSBoundParameters.ContainsKey('Dnssec'))     { $bodyHash.dnssec     = $Dnssec }
    if ($PSBoundParameters.ContainsKey('Profile'))    { $bodyHash.profile    = $Profile }
    if ($PSBoundParameters.ContainsKey('IsLocked'))   { $bodyHash.is_locked  = $IsLocked }
    if ($PSBoundParameters.ContainsKey('Forwarder'))  { $bodyHash.forwarder  = $Forwarder }
    if ($PSBoundParameters.ContainsKey('Tags'))       { $bodyHash.tags       = $Tags }

    $url = "https://mijn.host/api/v2/domains/$DomainName"
    Write-Verbose "Updating settings for domain '$DomainName'."
    Invoke-MijnHostApi -Method Put -Url $url -ApiKey $ApiKey -Body ([PSCustomObject]$bodyHash)
}
