
function Get-WEMPrinter {
    <#
.SYNOPSIS
    Retrieves printers from a WEM Configuration Set.
.DESCRIPTION
    This function gets a list of all configured printer actions from a specified WEM Configuration Set (Site).
.PARAMETER SiteId
    The ID of the WEM Configuration Set (Site) to query.
.PARAMETER IncludeAssignmentCount
    If specified, the result will include the count of assignments for each printer.
.EXAMPLE
    PS C:\> Get-WEMPrinter -BearerToken "xxxx" -CustomerId "yyyy" -SiteId 1
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
        [int]$SiteId,

        [Parameter(Mandatory = $false)]
        [switch]$IncludeAssignmentCount
    )

    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        $UriPath = "services/wem/webPrinter?siteId=$($SiteId)"
        if ($IncludeAssignmentCount.IsPresent) {
            $UriPath += "&getAssignmentCount=true"
        }

        $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "GET" -BearerToken $BearerToken -CustomerId $CustomerId
        return $Result.Items
    } catch {
        Write-Error "Failed to retrieve printers: $_"
        return $null
    }
}
