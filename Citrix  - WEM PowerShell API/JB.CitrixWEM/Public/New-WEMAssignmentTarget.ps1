function New-WEMAssignmentTarget {
<#
.SYNOPSIS
    Creates a new WEM assignment target from an Active Directory object.
.DESCRIPTION
    This function registers a new Active Directory user or group as an assignment target within a specified
    WEM Configuration Set. This allows actions, such as printers or applications, to be assigned to it.
    Requires an active session established by Connect-WemApi.
.PARAMETER Sid
    The Security Identifier (SID) of the Active Directory user or group.
.PARAMETER Name
    The fully qualified name of the object (e.g., 'DOMAIN/Path/GroupName').
.PARAMETER SiteId
    The ID of the WEM Configuration Set where this target will be created.
.PARAMETER ForestName
    The FQDN of the Active Directory forest where the object resides.
.PARAMETER Type
    The type of the object. Can be either 'Group' or 'User'. Defaults to 'Group'.
.PARAMETER DomainName
    The FQDN of the Active Directory domain. If not provided, it defaults to the same value as ForestName.
.PARAMETER Description
    An optional description for the assignment target.
.PARAMETER Enabled
    Specifies whether the assignment target is enabled. Defaults to $true.
.PARAMETER Priority
    Sets the priority for this target. Defaults to 100.
.EXAMPLE
    PS C:\> $AdGroup = Search-WEMActiveDirectoryObject -ForestName "domain.local" -Filter "ad_group_name"
    PS C:\> New-WEMAssignmentTarget -SiteId 19 -Name $AdGroup.name -Sid $AdGroup.sid -ForestName "domain.local" -Type "Group"

    First finds an AD group and then uses its properties to create a new assignment target in Site 19.
.NOTES
    Version:        1.0
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
    Creation Date:  2025-08-05
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Sid,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$ForestName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Group", "User")]
        [string]$Type = "Group",

        [Parameter(Mandatory = $false)]
        [string]$DomainName,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [bool]$Enabled = $true,

        [Parameter(Mandatory = $false)]
        [int]$Priority = 100
    )

    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        # Default the DomainName to the ForestName if it's not explicitly provided
        if (-not $PSBoundParameters.ContainsKey('DomainName')) {
            $DomainName = $ForestName
        }

        if ($PSCmdlet.ShouldProcess($Name, "Create WEM Assignment Target")) {
            # Construct the nested directoryContext object
            $DirectoryContext = [PSCustomObject]@{
                forest           = $ForestName
                domain           = $DomainName
                identityProvider = "AD"
                tenantId         = ""
            }

            # Construct the main request body
            $Body = @{
                sid              = $Sid
                type             = $Type
                name             = $Name
                description      = $Description
                siteId           = $SiteId
                enabled          = $Enabled
                priority         = $Priority
                directoryContext = $DirectoryContext
            }

            $Result = Invoke-WemApiRequest -UriPath "services/wem/assignmentTarget" -Method "POST" -Connection $Connection -Body $Body
            return $Result.Items
        }
    }
    catch {
        Write-Error "Failed to create WEM Assignment Target '$($Name)': $_"
        return $null
    }
}