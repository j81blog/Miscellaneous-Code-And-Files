function New-WEMApplication {
    <#
    .SYNOPSIS
        Creates a new application action in a WEM Configuration Set.
    .DESCRIPTION
        This function creates a new application shortcut action within a specified
        WEM Configuration Set (Site). If -SiteId is not specified, it uses the active
        Configuration Set defined by Set-WEMActiveConfigurationSite.
    .PARAMETER SiteId
        The ID of the WEM Configuration Set (Site) where the application will be created. Defaults to the active site.
    .PARAMETER DisplayName
        The name of the application shortcut to be displayed to the user.
    .PARAMETER CommandLine
        The command line executable path for the application.
    .PARAMETER IconStream
        A base64-encoded string of the icon to be used for the shortcut.
    .PARAMETER IconFile
        A path to an icon file. The file will be automatically converted to a base64 string.
    .EXAMPLE
        PS C:\> New-WEMApplication -DisplayName "My App" -CommandLine "C:\apps\app.exe" -IconFile "C:\icons\myicon.ico"

        Creates a new application shortcut named "My App" in the active Configuration Set, using a local icon file.
    .NOTES
        Version:        1.1
        Author:         John Billekens Consultancy
        Co-Author:      Gemini
        Creation Date:  2025-08-12
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'File')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [int]$SiteId,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$CommandLine,

        [Parameter(Mandatory = $true, ParameterSetName = 'Stream')]
        [string]$IconStream,

        [Parameter(Mandatory = $true, ParameterSetName = 'File')]
        [string]$IconFile,

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$StartMenuPath = "Start Menu\Programs",

        [Parameter(Mandatory = $false)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled")]
        [string]$State = "Enabled",

        [Parameter(Mandatory = $false)]
        [bool]$SelfHealing = $true,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Normal", "Minimized", "Maximized")]
        [string]$WindowStyle = "Normal",

        [Parameter(Mandatory = $false)]
        [switch]$PassThru
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

        if (-not $PSBoundParameters.ContainsKey('Name')) {
            $Name = $DisplayName
        }

        if ($PSCmdlet.ShouldProcess($DisplayName, "Create WEM Application in Site ID '$($ResolvedSiteId)'")) {

            if ($PSCmdlet.ParameterSetName -eq 'File') {
                Write-Verbose "Converting icon file '$($IconFile)' to base64 string..."
                $IconStream = Convert-IconFileToBase64 -Path $IconFile
            }

            $Body = @{
                siteId        = $ResolvedSiteId
                startMenuPath = $StartMenuPath
                state         = $State
                actionType    = "CreateAppShortcut"
                iconStream    = $IconStream
                description   = ""
                selfHealing   = $SelfHealing
                name          = $Name
                commandLine   = $CommandLine
                displayName   = $DisplayName
                hotKey        = "None"
                appType       = "InstallerApplication"
                windowsStyle  = $WindowStyle
            }
            if ($PSBoundParameters.ContainsKey('WorkingDirectory')) {
                $Body.Add('workingDir', $WorkingDirectory)
            }

            $UriPath = "services/wem/webApplications"
            $Result = Invoke-WemApiRequest -UriPath $UriPath -Method "POST" -Connection $Connection -Body $Body

            if ($PassThru.IsPresent) {
                $Result = Get-WEMApplication -SiteId $ResolvedSiteId | Where-Object { $_.name -eq $Name -and $_.commandLine -eq $CommandLine -and $_.startMenuPath -eq $StartMenuPath }
            }
            Write-Output ($Result | Expand-WEMResult -ErrorAction SilentlyContinue)
        }
    } catch {
        Write-Error "Failed to create WEM Application '$($DisplayName)': $($_.Exception.Message)"
        return $null
    }
}