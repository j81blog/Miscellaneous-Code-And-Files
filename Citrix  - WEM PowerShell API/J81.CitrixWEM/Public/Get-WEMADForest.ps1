function Get-WEMADForest {
<#
.SYNOPSIS
    Retrieves the configured Active Directory forests from WEM.
.DESCRIPTION
    This function retrieves a list of the Active Directory forests that are registered and recognized
    by the WEM service via its configured Cloud Connectors.
    Requires an active session established by Connect-WemApi.
.EXAMPLE
    PS C:\> Get-WEMADForest

    Returns a list of all configured forests.
.NOTES
    Version:        1.1
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
    Creation Date:  2025-08-05
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        $UriPath = "services/wem/forward/identity/Forests"

        $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "GET" -BearerToken $Connection.BearerToken -CustomerId $Connection.CustomerId

        # Consistent with other Get-* functions, return the 'Items' property which contains the array of results.
        return $Result.Items
    }
    catch {
        Write-Error "Failed to retrieve WEM AD Forests: $_"
        return $null
    }
}