function Search-WEMActiveDirectoryObject {
    <#
.SYNOPSIS
    Searches for Active Directory objects (users/groups) via the WEM service.
.DESCRIPTION
    This function performs a search for Active Directory users or groups within a specified forest and domain.
    The query is forwarded by the WEM service to the configured Cloud Connector.
    Requires an active session established by Connect-WemApi.
.PARAMETER ForestName
    The FQDN of the Active Directory forest to search in (e.g., 'yourcorp.local').
.PARAMETER Filter
    The search filter or query string to use for finding the object.
.PARAMETER DomainName
    The FQDN of the Active Directory domain to search in. If not provided, this defaults to the ForestName.
.PARAMETER SearchType
    Specifies the type of search to perform. For example, '2' appears to correspond to a 'Contains' search. Defaults to 2.
.PARAMETER MaxCount
    The maximum number of results to return from the search. Defaults to 100.
.EXAMPLE
    PS C:\> Search-WEMActiveDirectoryObject -ForestName "domain.local" -Filter "ad_group_name"

    Searches for objects in the 'domain.local' forest and domain where the name contains 'ad_group_name'.
.EXAMPLE
    PS C:\> $Domain = Get-WEMADForest | Get-WEMADDomain
    PS C:\> Search-WEMActiveDirectoryObject -ForestName $Domain.ForestName -DomainName $Domain.DomainName -Filter "ad_user_name"

    Searches for objects in the specified forest and domain where the name contains 'ad_user_name'.
.NOTES
    Version:        1.0
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
    Creation Date:  2025-08-05
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ForestName,

        [Parameter(Mandatory = $true)]
        [string]$Filter,

        [Parameter(Mandatory = $false)]
        [string]$DomainName,

        [Parameter(Mandatory = $false)]
        [int]$SearchType = 2,

        [Parameter(Mandatory = $false)]
        [int]$MaxCount = 100
    )

    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        # Default the DomainName to the ForestName if it's not explicitly provided
        if (-not $PSBoundParameters.ContainsKey('DomainName')) {
            $DomainName = $ForestName
        }

        # URL-encode the filter to handle spaces and special characters correctly
        $EncodedFilter = [System.Web.HttpUtility]::UrlEncode($Filter)

        # Construct the complex URI from the parameters
        if ($Connection.IsOnPrem -eq $true) {
            $UriPath = "services/wem/onPrem/identity/Forests/$($ForestName)/Domains/$($DomainName)/Users"
        } else {
            $UriPath = "services/wem/forward/identity/Forests/$($ForestName)/Domains/$($DomainName)/Users"
        }


        $UriPath += "?provider=AD&admin=&key=&queryOptions.take=$($MaxCount)&queryOptions.filter=$($EncodedFilter)&queryOptions.searchType=$($SearchType)"

        $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "GET" -Connection $Connection

        # The API nests the results in a 'results' property inside 'Items'
        if ($null -ne $Result.Items.results) {
            return $Result.Items.results
        } else {
            return $Result.Items
        }
    } catch {
        Write-Error "Failed to search Active Directory objects with filter '$($Filter)': $_"
        return $null
    }
}