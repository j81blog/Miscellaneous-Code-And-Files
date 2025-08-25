function Set-WEMApplication {
    <#
    .SYNOPSIS
        Updates an existing application action in a WEM Configuration Set.
    .DESCRIPTION
        This function updates the properties of an existing application action. You must provide the ID
        of the application to modify. Other parameters are optional. If -SiteId is not specified,
        it uses the active Configuration Set defined by Set-WEMActiveConfigurationSite.
    .PARAMETER Id
        The unique ID of the application action to update.
    .PARAMETER SiteId
        The ID of the WEM Configuration Set where the application exists. Defaults to the active site.
    .PARAMETER IconStream
        A base64-encoded string of the icon to be used for the shortcut.
    .PARAMETER IconFile
        A path to an icon file. The file will be automatically converted to a base64 string.
    .EXAMPLE
        PS C:\> Set-WEMApplication -Id 459 -IconFile "C:\icons\new_icon.ico"

        Updates the icon for the application with ID 459 using a local file.
    .NOTES
        Version:        1.2
        Author:         John Billekens Consultancy
        Co-Author:      Gemini
        Creation Date:  2025-08-12
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'Stream')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$Id,

        [Parameter(Mandatory = $false)]
        [int]$SiteId,

        [Parameter(Mandatory = $false, ParameterSetName = 'Stream')]
        [string]$IconStream,

        [Parameter(Mandatory = $false, ParameterSetName = 'File')]
        [string]$IconFile,

        [Parameter(Mandatory = $false)]
        [string]$DisplayName,

        [Parameter(Mandatory = $false)]
        [string]$CommandLine,

        [Parameter(Mandatory = $false)]
        [string]$StartMenuPath,

        [Parameter(Mandatory = $false)]
        [string]$Parameter,

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string]$State,

        [Parameter(Mandatory = $false)]
        [bool]$SelfHealing,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Normal", "Minimized", "Maximized")]
        [string]$WindowStyle,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Description
    )

    try {
        $Connection = Get-WemApiConnection

        $ResolvedSiteId = 0
        if ($PSBoundParameters.ContainsKey('SiteId')) {
            $ResolvedSiteId = $SiteId
        } elseif ($Connection.ActiveSiteId) {
            $ResolvedSiteId = $Connection.ActiveSiteId
            Write-Verbose "Using active Configuration Set '$($Connection.ActiveSiteName)' (ID: $ResolvedSiteId)"
        } else {
            throw "No -SiteId was provided, and no active Configuration Set has been set. Please use Set-WEMActiveConfigurationSite or specify the -SiteId parameter."
        }

        $TargetDescription = "WEM Application with ID '$($Id)' in Site ID '$($ResolvedSiteId)'"
        if ($PSCmdlet.ShouldProcess($TargetDescription, "Update")) {

            # If -IconFile was used, convert it and populate the $IconStream variable
            if ($PSCmdlet.ParameterSetName -eq 'File') {
                Write-Verbose "Converting icon file '$($IconFile)' to base64 string..."
                $IconStream = Convert-IconFileToBase64 -Path $IconFile
            }

            # Build the application object with only the properties that were provided
            $AppObject = @{
                id     = $Id
                siteId = $ResolvedSiteId
            }
            if ($PSBoundParameters.ContainsKey('DisplayName')) { $AppObject.Add('displayName', $DisplayName) }
            if ($PSBoundParameters.ContainsKey('CommandLine')) { $AppObject.Add('commandLine', $CommandLine) }
            if ($PSBoundParameters.ContainsKey('Parameter')) { $AppObject.Add('parameter', $Parameter) }
            if ($PSBoundParameters.ContainsKey('IconStream') -or $PSBoundParameters.ContainsKey('IconFile')) { $AppObject.Add('iconStream', $IconStream) }
            if ($PSBoundParameters.ContainsKey('StartMenuPath')) { $AppObject.Add('startMenuPath', $StartMenuPath) }
            if ($PSBoundParameters.ContainsKey('WorkingDirectory')) { $AppObject.Add('workingDir', $WorkingDirectory) }
            if ($PSBoundParameters.ContainsKey('State')) { $AppObject.Add('state', $State) }
            if ($PSBoundParameters.ContainsKey('SelfHealing')) { $AppObject.Add('selfHealing', $SelfHealing) }
            if ($PSBoundParameters.ContainsKey('WindowStyle')) { $AppObject.Add('windowsStyle', $WindowStyle) }
            if ($PSBoundParameters.ContainsKey('Name')) { $AppObject.Add('name', $Name) }
            if ($PSBoundParameters.ContainsKey('Description')) { $AppObject.Add('description', $Description) }

            $Body = @{ applicationList = @($AppObject) }

            $UriPath = "services/wem/webApplications"
            $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "PUT" -Connection $Connection -Body $Body
            Write-Output ($Result | Expand-WEMResult)
        }
    } catch {
        Write-Error "Failed to update WEM Application with ID '$($Id)': $($_.Exception.Message)"
    }
}