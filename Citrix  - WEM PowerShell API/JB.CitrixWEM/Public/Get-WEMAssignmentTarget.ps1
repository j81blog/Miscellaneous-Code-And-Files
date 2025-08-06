function Get-WEMAssignmentTarget {
<#
.SYNOPSIS
    Retrieves assignment targets (like AD objects) from a WEM Configuration Set.
.DESCRIPTION
    This function queries and retrieves a list of assignment targets, such as users and groups,
    from a specific WEM Configuration Set (Site).
.PARAMETER SiteId
    The ID of the WEM Configuration Set (Site) to query for assignment targets.
.EXAMPLE
    PS C:\> Get-WEMAssignmentTarget -SiteId 1

    Retrieves all assignment targets associated with Site ID 1.
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
        [int]$SiteId
    )

    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        # Build the specific filter structure required by the API
        $Filter = [PSCustomObject]@{
            param    = "SiteId"
            operator = "Equals"
            value    = $SiteId
        }

        $Body = @{
            filters = @($Filter)
        }

        $Result = Invoke-WemApiRequest -UriPath "services/wem/assignmentTarget/`$query" -Method "POST" -Connection $Connection -Body $Body
        return $Result.Items
    }
    catch {
        Write-Error "Failed to retrieve WEM Assignment Targets for Site ID $($SiteId): $_"
        return $null
    }
}