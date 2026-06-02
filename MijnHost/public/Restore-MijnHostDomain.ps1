function Restore-MijnHostDomain {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    if (-not $PSCmdlet.ShouldProcess("Domain '$DomainName'", 'Restore cancelled domain')) { return }

    $url = "https://mijn.host/api/v2/domains/$DomainName/cancel-delete"
    Write-Verbose "Restoring cancelled domain '$DomainName'."
    Invoke-MijnHostApi -Method Put -Url $url -ApiKey $ApiKey
}
