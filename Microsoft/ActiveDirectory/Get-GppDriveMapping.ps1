function Get-GppDriveMapping {
    <#
    .SYNOPSIS
        Retrieves Group Policy Preference (GPP) drive mappings from a specified GPO, including
        Item-Level Targeting for security groups.

    .DESCRIPTION
        This function generates an XML report of a GPO and parses it to extract configured
        GPP drive mappings. It also inspects Item-Level Targeting filters to identify if the
        mapping is targeted to a specific Active Directory security group.

    .PARAMETER GpoName
        The display name of the Group Policy Object to query.
        This parameter is mandatory and supports pipeline input.

    .EXAMPLE
        PS C:\> Get-GppDriveMapping -GpoName "Standaard Werkplek Policy"

        GpoName           : Standaard Werkplek Policy
        Action            : Update
        DriveLetter       : H:
        Location          : \\server\share\users\%username%
        Label             : Home Drive
        Status            : Enabled
        TargetedAdGroup   : Domein Gebruikers

        This command retrieves drive mappings and their targeted AD groups from the specified GPO.

    .NOTES
        Version      : 1.3
        Author       : John Billekens Consultancy
        Co-Author    : Gemini
        CreationDate : 2025-08-26
        Requires     : ActiveDirectory and GroupPolicy PowerShell modules.
                       Permissions to read GPOs and AD groups.
#>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            HelpMessage = "Enter the name of the GPO."
        )]
        [ValidateNotNullOrEmpty()]
        [string[]]$GpoName,

        [switch]$AsJson
    )

    begin {
        # Check if the required modules are available
        if (-not (Get-Module -ListAvailable -Name GroupPolicy)) {
            Write-Error "The GroupPolicy module is required. Please install it via 'Install-WindowsFeature GPMC'."
            return
        }
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            Write-Error "The ActiveDirectory module is required. Please install it via RSAT."
            return
        }
        $ActionMap = @{
            C = "Create"
            R = "Replace"
            U = "Update"
            D = "Delete"
        }
    }

    process {
        foreach ($Name in $GpoName) {
            try {
                Write-Verbose "Processing GPO: '$Name'"
                $GpoReportXml = Get-GPOReport -Name $Name -ReportType Xml -ErrorAction Stop
                [xml]$XmlData = $GpoReportXml

                $DriveNodes = @($XmlData.GPO.User.ExtensionData.Extension.DriveMapSettings.Drive)
                $Output = $null

                if ($null -ne $DriveNodes -and $DriveNodes.Count -gt 0) {
                    foreach ($Drive in $DriveNodes) {
                        # --- New logic to find targeted AD groups ---
                        $TargetedGroup = @()
                        $FilterNodes = $Drive.Filters.FilterGroup
                        if ($null -ne $Drive.Filters.FilterCollection) {
                            $FilterNodes += $Drive.Filters.FilterCollection.FilterGroup
                        }

                        if ($null -ne $FilterNodes) {
                            $GroupSids = $FilterNodes | Where-Object { $_.sid } | Select-Object -ExpandProperty sid
                            foreach ($Sid in $GroupSids) {
                                try {
                                    $Name = (Get-ADGroup -Identity $Sid -ErrorAction Stop).Name
                                    $TargetedGroup += [PSCustomObject]@{
                                        Sid  = $Sid
                                        Name = $Name
                                    }
                                } catch {
                                    Write-Warning "Could not resolve SID '$Sid' to an AD Group name."
                                    "SID:$($Sid) (Unresolved)"
                                }
                            }
                        }
                        if ($TargetedGroup.Count -eq 0) {
                            $TargetedGroup += [PSCustomObject]@{ Sid = "S-1-1-0"; Name = "Everyone" }
                        }
                        $Action = $ActionMap[$Drive.Properties.action]
                        if (-not $Action) {
                            $Action = $Drive.Properties.action
                        }
                        if ($Drive.disabled -eq "1") {
                            $Enabled = $false
                        } else {
                            $Enabled = $true
                        }

                        # Create the output object
                        $Output = [PSCustomObject]@{
                            GpoName           = $Name
                            Action            = $Action
                            DriveLetter       = $Drive.Properties.letter
                            NetworkPath       = $Drive.Properties.path
                            Label             = $Drive.Properties.label
                            Persistent        = [bool][int]$Drive.Properties.persistent
                            UseDriveLetter    = [bool][int]$Drive.Properties.useletter
                            HideShowDrive     = $Drive.Properties.thisDrive
                            HideShowAllDrives = $Drive.Properties.allDrives
                            Status            = $Drive.status
                            TargetedAdGroup   = @($TargetedGroup)
                            Enabled           = $Enabled
                        }
                    }
                    if ($AsJson) {
                        Write-Output ($Output | ConvertTo-Json -Depth 5)
                    } else {
                        Write-Output $Output
                    }
                } else {
                    Write-Verbose "No GPP Drive Mappings found in GPO '$Name'."
                }
            } catch {
                Write-Warning "Could not retrieve or parse GPO '$Name'. Error: $($_.Exception.Message)"
            }
        }
    }
}