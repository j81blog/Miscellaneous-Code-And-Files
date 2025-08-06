function New-WEMPrinterAssignment {
    <#
.SYNOPSIS
    Assigns a WEM printer action to a target (user/group).
.DESCRIPTION
    This function creates a new assignment for a WEM printer, linking it to a specific target and optionally applying a filter.
.PARAMETER SiteId
    The ID of the WEM Configuration Set (Site).
.PARAMETER ResourceId
    The ID of the printer resource/action that you want to assign.
.PARAMETER TargetId
    The ID of the target (e.g., Active Directory group or user) to which the printer will be assigned.
.PARAMETER FilterId
    The ID of the filter to apply to this assignment. Defaults to 1 (Always True).
.PARAMETER SetAsDefault
    Specifies if this printer should be set as the default printer for the target.
.EXAMPLE
    PS C:\> New-WEMPrinterAssignment -BearerToken "xxxx" -CustomerId "yyyy" -SiteId 1 -ResourceId 132 -TargetId 63 -SetAsDefault
.NOTES
    Version:        1.0
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
    Creation Date:  2025-08-05
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SiteId,

        [Parameter(Mandatory = $true)]
        [int]$ResourceId,

        [Parameter(Mandatory = $true)]
        [int]$TargetId,

        [Parameter(Mandatory = $false)]
        [int]$FilterId = 1,

        [Parameter(Mandatory = $false)]
        [switch]$SetAsDefault
    )
    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        $TargetDescription = "TargetID: $($TargetId)" # You might want to resolve this to a name for better ShouldProcess messages.
        if ($PSCmdlet.ShouldProcess($TargetDescription, "Assign WEM Printer (ID: $($ResourceId))")) {
            $Body = @{
                siteId     = $SiteId
                resourceId = $ResourceId
                targetId   = $TargetId
                filterId   = $FilterId
                isDefault  = $SetAsDefault.IsPresent
            }

            $Result = Invoke-WemApiRequest -UriPath "services/wem/printerAssignment" -Method "POST" -Connection $Connection -Body $Body
            return $Result.Items
        }
    } catch {
        Write-Error "Failed to assign printer: $_"
        return $null
    }
}

