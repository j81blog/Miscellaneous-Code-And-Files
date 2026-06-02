function Remove-MijnHostDomain {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    if (-not $PSCmdlet.ShouldProcess("Domain '$DomainName'", 'Cancel domain registration')) { return }

    $url = "https://mijn.host/api/v2/domains/$DomainName"
    Write-Verbose "Cancelling domain registration for '$DomainName'."
    Invoke-MijnHostApi -Method Delete -Url $url -ApiKey $ApiKey
}
