function Get-WEMActionSettings {
    <#
.SYNOPSIS
    Retrieves advanced action settings from a WEM Configuration Set.
.DESCRIPTION
    This function gets the advanced settings related to actions from a specified WEM Configuration Set (Site).
.PARAMETER BearerToken
    The authentication bearer token for the API session.
.PARAMETER CustomerId
    The Citrix Customer ID.
.PARAMETER SiteId
    The ID of the WEM Configuration Set (Site) to query.
.EXAMPLE
    PS C:\> Get-WEMActionSettings -BearerToken "xxxx" -CustomerId "yyyy" -SiteId 1
.NOTES
    Version:        1.0
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
    Creation Date:  2025-08-05
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BearerToken = $script:WemApiConnection.BearerToken,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[a-zA-Z0-9-]+$")]
        [string]$CustomerId = $script:WemApiConnection.CustomerId,

        [Parameter(Mandatory = $true)]
        [int]$SiteId
    )
    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        $UriPath = "services/wem/advancedSetting/actionSettings?siteId=$($SiteId)"
        $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "GET" -BearerToken $BearerToken -CustomerId $CustomerId
        return $Result.Items
    } catch {
        Write-Error "Failed to retrieve action settings: $_"
        return $null
    }
}
