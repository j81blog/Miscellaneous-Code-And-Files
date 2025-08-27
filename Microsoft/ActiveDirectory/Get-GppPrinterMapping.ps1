function Get-GppPrinterMapping {
    <#
    .SYNOPSIS
        Retrieves GPP shared printer mappings from a GPO, including Item-Level Targeting.

    .DESCRIPTION
        This function generates an XML report of a GPO and parses it to extract configured
        GPP Shared Printer mappings. It also inspects Item-Level Targeting filters to identify
        if the mapping is targeted to a specific Active Directory security group.

    .PARAMETER GpoName
        The display name of the Group Policy Object to query.
        This parameter is mandatory and supports pipeline input.

    .EXAMPLE
        PS C:\> Get-GppPrinterMapping -GpoName "Printers Kantoor Policy"

        GpoName         : Printers Kantoor Policy
        Action          : Update
        PrinterPath     : \\PRINTSERVER\Printer-Finance
        IsDefault       : False
        Status          : Enabled
        TargetedAdGroup : Finance Department

        This command retrieves printer mappings and their targeted AD groups.

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
        [Parameter( Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Enter the name of the GPO." )]
        [ValidateNotNullOrEmpty()]
        [string[]]$GpoName
    )

    begin {
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

                $PrinterNodes = $XmlData.GPO.User.ExtensionData.Extension.Printers.SharedPrinter

                if ($null -ne $PrinterNodes) {
                    foreach ($Printer in $PrinterNodes) {
                        $TargetedGroup = @()
                        $FilterNodes = $Printer.Filters.FilterGroup
                        if ($null -ne $Printer.Filters.FilterCollection) {
                            $FilterNodes += $Printer.Filters.FilterCollection.FilterGroup
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
                        if ($Printer.disabled -eq "1") {
                            $Enabled = $false
                        } else {
                            $Enabled = $true
                        }

                        [PSCustomObject]@{
                            GpoName         = $Name
                            Action          = $Printer.Properties.action
                            PrinterPath     = $Printer.Properties.path
                            IsDefault       = [bool][int]$Printer.Properties.default
                            Comment         = $Printer.Properties.comment
                            Persistent      = [bool][int]$Printer.Properties.persistent
                            Status          = $Printer.name
                            TargetedAdGroup = @($TargetedGroup)
                            Enabled         = $Enabled
                        }
                    }
                } else {
                    Write-Verbose "No GPP Shared Printer Mappings found in GPO '$Name'."
                }
            } catch {
                Write-Warning "Could not retrieve or parse GPO '$Name'. Error: $($_.Exception.Message)"
            }
        }
    }
}