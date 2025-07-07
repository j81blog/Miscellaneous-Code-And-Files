function New-MijnHostDNSRecord {
    [CmdletBinding()]
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

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [PSCustomObject[]]$Records
    )
    $domainRecord = $Records | Where-Object { $_.domain -ieq $DomainName }
    if (-Not $domainRecord) {
        $domainRecord = [PSCustomObject]@{
            domain  = $DomainName
            records = @([PSCustomObject]@{
                    name  = $Name
                    type  = $Type
                    value = $Value
                    ttl   = $TTL
                }
            )
        }
        $Records += $domainRecord
    } else {
        $domainRecord.records += [PSCustomObject]@{
            name  = $Name
            type  = $Type
            value = $Value
            ttl   = $TTL
        }
    }
    return $Records
}
