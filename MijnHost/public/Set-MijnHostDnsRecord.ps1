function Set-MijnHostDnsRecord {
    [CmdletBinding(DefaultParameterSetName = 'SingleRecord', SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'SingleRecord')]
        [Alias('Domain')]
        [string]$DomainName,

        [Parameter(Mandatory, ParameterSetName = 'SingleRecord')]
        [Parameter(Mandatory, ParameterSetName = 'AllRecords')]
        [string]$ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'AllRecords')]
        [PSCustomObject[]]$Records,

        [Parameter(Mandatory, ParameterSetName = 'SingleRecord')]
        [ValidateSet('A', 'AAAA', 'CNAME', 'MX', 'TXT', 'SRV', 'NS', 'CAA', 'PTR', 'SOA')]
        [string]$Type,

        [Parameter(Mandatory, ParameterSetName = 'SingleRecord')]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'SingleRecord')]
        [string]$Value,

        [Parameter(ParameterSetName = 'SingleRecord')]
        [int]$TTL = 900
    )

    if ($PSCmdlet.ParameterSetName -eq 'SingleRecord') {
        Write-Verbose "Preparing to set a single DNS record."
        $body = @{
            record = @{
                name  = $Name
                type  = $Type
                value = $Value
                ttl   = $TTL
            }
        }
        $Method = 'PATCH'
        $url = "https://mijn.host/api/v2/domains/$DomainName/dns"

        Invoke-MijnHostApi -Method $Method -Url $url -ApiKey $ApiKey -Body $body
    }

    if ($PSCmdlet.ParameterSetName -eq 'AllRecords') {
        ForEach ($domainRecord in $Records) {
            if (-not $PSCmdlet.ShouldProcess("DNS records for domain '$($domainRecord.Domain)'", "Overwrite ALL DNS records with new records payload")) {
                return
            }
            $domainRecords = [PSCustomObject]@{
                records = @($Records.records)
            }
            Write-Verbose "Preparing to overwrite ALL DNS records."
            $body = $domainRecords
            $Method = 'PUT'
            $url = "https://mijn.host/api/v2/domains/$($domainRecord.Domain)/dns"

            Invoke-MijnHostApi -Method $Method -Url $url -ApiKey $ApiKey -Body $body
        }
    }
}
