
function New-WEMPrinter {
    <#
.SYNOPSIS
    Creates a new network printer in Citrix WEM.
.DESCRIPTION
    This function adds a new network printer action to a specified WEM Configuration Set (Site).
.PARAMETER SiteId
    The ID of the WEM Configuration Set (Site) where the printer will be created.
.PARAMETER PrinterPath
    The UNC path of the network printer (e.g., \\server\printer).
.PARAMETER DisplayName
    The name of the printer to be displayed to the user.
.PARAMETER Description
    An optional description for the printer action.
.PARAMETER Enabled
    Specifies whether the printer action is enabled. Defaults to $true.
.PARAMETER SelfHealing
    Enables or disables the self-healing feature for this printer. Defaults to $false.
.PARAMETER UseCredential
    Specifies whether to use alternate credentials for the connection. Defaults to $false.
.EXAMPLE
    PS C:\> New-WEMPrinter -BearerToken "xxxx" -CustomerId "abcdef123" -SiteId 1 -PrinterPath "\\printserver01.domain.local\ITPrinter" -DisplayName "IT Department Printer"
.NOTES
    Version:        1.0
    Author:         John Billekens Consultancy
    Co-Author:      Gemini
#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [int]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$PrinterPath,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $false)]
        [bool]$Enabled = $true,

        [Parameter(Mandatory = $false)]
        [bool]$SelfHealing = $true
    )
    try {
        # Get connection details. Throws an error if not connected.
        $Connection = Get-WemApiConnection

        if ($PSCmdlet.ShouldProcess($PrinterPath, "Create WEM Printer")) {
            $Body = @{
                siteId        = $SiteId
                enabled       = $Enabled
                actionType    = "NetWorkPrinter"
                useCredential = $false
                selfHealing   = $SelfHealing
                displayName   = $DisplayName
                name          = $PrinterPath
                targetPath    = $PrinterPath
            }
            if (-not [String]::IsNullOrEmpty($Description)) {
                $Body.description = $Description
            }

            $Result = Invoke-WemApiRequest -UriPath "services/wem/webPrinter" -Method "POST" -Connection $Connection -Body $Body
            return $Result.Items

        }
    } catch {
        Write-Error "Failed to create printer: $_"
        return $null
    }
}
