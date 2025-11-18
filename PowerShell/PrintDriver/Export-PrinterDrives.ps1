function Export-PrinterDrives {
    <#
    .SYNOPSIS
        Exports printer drivers currently in use to an organized directory structure

    .DESCRIPTION
        This function exports all printer drivers that are actively used by configured printers on the system.
        It uses pnputil.exe to export driver packages, then organizes them into folders named by manufacturer,
        version, and environment. Each driver package includes the INF files and a JSON metadata file containing
        driver information such as names, version, manufacturer, and printer environment.

        The function only exports drivers that are in use by actual printers (excluding generic drivers),
        deduplicates drivers by version, and provides comprehensive error handling and progress feedback.

    .OUTPUTS
        [PSCustomObject] (only when -PassThru is specified)
        Returns an object with the following properties:
        - Success: Boolean indicating if export completed without errors
        - DriversExported: Number of drivers successfully exported
        - TotalDrivers: Total number of drivers processed
        - ExportPath: Path where drivers were exported
        - Drivers: Array of exported driver objects with details
        - Errors: Array of error messages encountered during export

        Without -PassThru, returns null and only displays informational messages.

    .PARAMETER ExportPath
        The root directory where printer drivers will be exported. Defaults to "C:\DriversExport".
        The function will create this directory if it doesn't exist and will validate sufficient disk space.

    .PARAMETER Exclusions
        Array of printer driver names to exclude from export. Defaults to:
        - "Generic / Text Only"
        - "Microsoft XPS Document Writer"
        - "Microsoft XPS Document Writer v4"
        - "Microsoft Print to PDF"
        You can provide your own list to exclude additional or different drivers.

    .PARAMETER PassThru
        When specified, returns a detailed PSCustomObject with export results including success status,
        driver count, errors, and exported driver details. Without this switch, the function returns null
        and only displays informational messages.

    .EXAMPLE
        PS C:\> Export-PrinterDrives
        Exports all printer drivers to the default location C:\DriversExport (no return value)

    .EXAMPLE
        PS C:\> Export-PrinterDrives -ExportPath "D:\PrinterBackup"
        Exports all printer drivers to D:\PrinterBackup

    .EXAMPLE
        PS C:\> $result = Export-PrinterDrives -ExportPath "D:\PrinterBackup" -PassThru -Verbose
        PS C:\> if ($result.Success) { Write-Information "Successfully exported $($result.DriversExported) drivers" }
        Exports drivers with verbose output, returns results object, and checks the result

    .EXAMPLE
        PS C:\> $result = Export-PrinterDrives -ExportPath "E:\Backup" -PassThru
        PS C:\> $result.Drivers | Format-Table Manufacturer, Version, DriverNames
        Exports drivers and displays a summary table of what was exported

    .EXAMPLE
        PS C:\> Export-PrinterDrives -ExportPath "D:\Backup" -exclusions @("Generic / Text Only", "Fax")
        Exports drivers excluding the specified driver names

    .EXAMPLE
        PS C:\> Export-PrinterDrives -InformationAction SilentlyContinue
        Exports drivers without displaying progress messages (silent mode)

    .EXAMPLE
        PS C:\> Export-PrinterDrives -InformationVariable exportMessages
        PS C:\> $exportMessages | Out-File "export-log.txt"
        Exports drivers and captures all informational messages to a log file

    .EXAMPLE
        PS C:\> $result = Export-PrinterDrives -PassThru
        PS C:\> if (-not $result.Success) { $result.Errors | ForEach-Object { Write-Warning $_ } }
        Exports drivers with PassThru and displays any errors that occurred

    .EXAMPLE
        PS C:\> Export-PrinterDrives -ExportPath "D:\Backup" -Exclusions @("Generic / Text Only")
        Exports drivers with custom exclusions (no return value without PassThru)

    .NOTES
        Function  : Export-PrinterDrives
        Author    : John Billekens
        CoAuthor  : Claude (Anthropic)
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 1.1

        Requirements:
        - Administrator privileges (required for Get-PrinterDriver and pnputil.exe)
        - Windows PowerShell 5.1 or PowerShell 7+
        - PrintManagement module (typically built-in on Windows)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$ExportPath = "C:\DriversExport",

        [string[]]$Exclusions = @(
            "Generic / Text Only",
            "Microsoft XPS Document Writer",
            "Microsoft XPS Document Writer v4",
            "Microsoft Print to PDF"
        ),

        [switch]$PassThru
    )
    #requires -Module PrintManagement
    #requires -RunAsAdministrator
    try {
        # Validate and create export path
        if (-not $ExportPath) {
            throw "ExportPath cannot be empty"
        }

        Write-Verbose "Validating export path: $ExportPath"
        if (-not (Test-Path -Path $ExportPath)) {
            Write-Verbose "Creating export directory: $ExportPath"
            New-Item -Path $ExportPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        # Check for sufficient disk space (at least 500MB free)
        $drive = Split-Path -Path $ExportPath -Qualifier
        $diskInfo = Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction Stop
        $freeSpaceGB = [math]::Round($diskInfo.Free / 1GB, 2)
        if ($diskInfo.Free -lt 500MB) {
            Write-Warning "Low disk space on $drive - Only $freeSpaceGB GB available"
        }

        $exportTempPath = Join-Path -Path $ExportPath -ChildPath "Temp"

        Write-Verbose "Creating temporary export directory: $exportTempPath"
        New-Item -Path $exportTempPath -ItemType Directory -Force -ErrorAction Stop | Out-Null

        Write-Information "Retrieving installed printer drivers..." -InformationAction Continue -Tags "Progress"
        $printerDriversInstalled = Get-PrinterDriver -ErrorAction Stop | Where-Object { $_.InfPath -notmatch "printqueue.dll" }

        Write-Information "Retrieving configured printers..." -InformationAction Continue -Tags "Progress"
        $printerDriversRequired = Get-Printer -ErrorAction Stop |
            Select-Object -ExpandProperty DriverName |
            Where-Object { $_ -notin $Exclusions } |
            Sort-Object -Unique

        if ($printerDriversRequired.Count -eq 0) {
            Write-Warning "No printer drivers found to export"
            return [PSCustomObject]@{
                Success         = $true
                DriversExported = 0
                ExportPath      = $ExportPath
                Drivers         = @()
                Errors          = @()
            }
        }

        Write-Information "Exporting drivers using pnputil (this may take a few minutes)..." -InformationAction Continue -Tags "Progress"
        $output = & pnputil.exe /Export-Driver * "$exportTempPath" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "pnputil.exe failed with exit code $LASTEXITCODE. Output: $output"
        }

        $driverExports = @()
        $errors = @()
        $currentDriver = 0
        $totalDrivers = $printerDriversRequired.Count

        # Get Windows DriverStore path dynamically
        $driverStorePath = Join-Path -Path $env:SystemRoot -ChildPath "System32\DriverStore\FileRepository\"

        Write-Information "Processing $totalDrivers printer drivers..." -InformationAction Continue -Tags "Progress"

        foreach ($printDriver in $printerDriversRequired) {
            $currentDriver++
            $percentComplete = [math]::Round(($currentDriver / $totalDrivers) * 100)
            Write-Progress -Activity "Processing Printer Drivers" -Status "Processing: $printDriver ($currentDriver of $totalDrivers)" -PercentComplete $percentComplete

            try {
                if ($driverFound = $printerDriversInstalled | Where-Object { $_.Name -ieq $printDriver }) {
                    $driverInfPath = $driverFound.InfPath

                    # Extract relative path from driver store
                    if ($driverInfPath -match [regex]::Escape($driverStorePath)) {
                        $driverFilename = $driverInfPath -replace [regex]::Escape($driverStorePath), ''
                    } else {
                        # Fallback: try to extract just the filename and parent folder
                        $driverFilename = Join-Path -Path (Split-Path -Path $driverInfPath -Parent | Split-Path -Leaf) -ChildPath (Split-Path -Path $driverInfPath -Leaf)
                    }

                    $driverParentFolder = Split-Path -Path $driverFilename -Parent

                    $major = ($driverFound.DriverVersion -shr 48) -band 0xFFFF
                    $minor = ($driverFound.DriverVersion -shr 32) -band 0xFFFF
                    $build = ($driverFound.DriverVersion -shr 16) -band 0xFFFF
                    $revision = $driverFound.DriverVersion -band 0xFFFF
                    $driverVersion = "$major.$minor.$build.$revision"

                    if ($driverExport = $driverExports | Where-Object { $_.Id -ieq $driverParentFolder -and $_.Version -ieq $driverVersion }) {
                        if ($driverExport.DriverNames -notcontains $driverFound.Name) {
                            $driverExport.DriverNames += $driverFound.Name
                        }
                    } else {
                        $driverExports += [PSCustomObject]@{
                            Id                 = $driverParentFolder
                            Manufacturer       = $driverFound.Manufacturer
                            Version            = $driverVersion
                            InfPath            = ""
                            InfFileName        = ""
                            PrinterEnvironment = $driverFound.PrinterEnvironment
                            DriverNames        = @($driverFound.Name)
                        }
                        $driverExport = $driverExports | Where-Object { $_.Id -ieq $driverParentFolder }
                    }

                    $driver = Get-ChildItem -Path $exportTempPath -Filter $driverFilename -Recurse -ErrorAction SilentlyContinue
                    if ($driver) {
                        Write-Verbose "Driver $($driverFound.Name) found at $($driver.FullName)"
                        $driverPath = Split-Path -Path $driver.FullName -Parent
                        $driverExport.InfFileName = $driver.Name
                        $driverExport.InfPath = $driverPath
                    } else {
                        $errorMsg = "Driver $($driverFound.Name) not found in export path"
                        Write-Warning $errorMsg
                        $errors += $errorMsg
                    }
                } else {
                    $errorMsg = "Driver '$printDriver' not found in installed drivers"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                }
            } catch {
                $errorMsg = "Error processing driver '$printDriver': $($_.Exception.Message)"
                Write-Error $errorMsg
                $errors += $errorMsg
            }
        }

        Write-Progress -Activity "Processing Printer Drivers" -Completed

        Write-Information "Organizing exported drivers..." -InformationAction Continue -Tags "Progress"
        $successfulExports = 0

        foreach ($item in $driverExports) {
            try {
                if (-not $item.InfPath) {
                    Write-Warning "Skipping driver without valid export path: $($item.DriverNames -join ', ')"
                    continue
                }

                $folderName = '{0}_{1}_{2}' -f $item.Manufacturer, $item.Version, $item.PrinterEnvironment
                $folderName = $folderName -replace '[^a-zA-Z0-9_\.]', '_'
                $newPath = Join-Path -Path $ExportPath -ChildPath $folderName

                if (-not (Test-Path -Path $newPath)) {
                    New-Item -Path $newPath -ItemType Directory -ErrorAction Stop | Out-Null
                }

                Write-Verbose "Copying driver files to: $newPath"
                Copy-Item -Path $item.InfPath -Destination $newPath -Recurse -Force -ErrorAction Stop | Out-Null

                $item.InfPath = Split-Path -Path $item.InfPath -Leaf
                $jsonPath = Join-Path -Path $newPath -ChildPath "$($folderName).json"
                $item | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding UTF8 -ErrorAction Stop

                Write-Information "Exported: $($item.DriverNames -join ', ') -> $folderName" -InformationAction Continue -Tags "Success"
                $successfulExports++
            } catch {
                $errorMsg = "Error organizing driver '$($item.DriverNames -join ', ')': $($_.Exception.Message)"
                Write-Error $errorMsg
                $errors += $errorMsg
            }
        }

        Write-Information "Export complete: $successfulExports of $($driverExports.Count) drivers exported successfully" -InformationAction Continue -Tags "Complete"

        if ($PassThru) {
            Write-Verbose "PassThru specified - returning detailed results object"
            # Return results object
            return [PSCustomObject]@{
                Success         = ($errors.Count -eq 0)
                DriversExported = $successfulExports
                TotalDrivers    = $driverExports.Count
                ExportPath      = $ExportPath
                Drivers         = $driverExports
                Errors          = $errors
            }
        } else {
            Write-Verbose "No PassThru specified - not returning detailed results object"
            return $null
        }

    } catch {
        Write-Error "Critical error during export: $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success         = $false
            DriversExported = 0
            ExportPath      = $ExportPath
            Drivers         = @()
            Errors          = @($_.Exception.Message)
        }
    } finally {
        # Clean up temporary export directory
        if (Test-Path -Path $exportTempPath) {
            Write-Verbose "Cleaning up temporary directory: $exportTempPath"
            try {
                Remove-Item -Path $exportTempPath -Recurse -Force -ErrorAction Stop | Out-Null
            } catch {
                Write-Warning "Failed to remove temporary directory: $($_.Exception.Message)"
            }
        }
    }
}