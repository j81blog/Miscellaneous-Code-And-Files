function Install-PrinterDrivers {
    <#
    .SYNOPSIS
        Installs printer drivers from an exported driver directory structure

    .DESCRIPTION
        This function installs printer drivers that were previously exported using Export-PrinterDrives.
        It reads JSON metadata files from the source directory, uses pnputil.exe to add driver packages
        to the Windows driver store, and then installs the printer drivers using Add-PrinterDriver.

        The function processes all JSON files matching the pattern "*_*_*.json" in the source directory,
        validates INF file paths, and provides comprehensive error handling and progress feedback.

    .OUTPUTS
        [PSCustomObject] (only when -PassThru is specified)
        Returns an object with the following properties:
        - Success: Boolean indicating if all installations completed without errors
        - DriversInstalled: Number of driver packages successfully installed
        - TotalDrivers: Total number of driver packages processed
        - SourcePath: Path where drivers were imported from
        - InstalledDrivers: Array of installed driver details
        - Errors: Array of error messages encountered during installation

        Without -PassThru, returns null and only displays informational messages.

    .PARAMETER SourcePath
        The root directory containing exported printer drivers. This should be the path where
        Export-PrinterDrives stored the driver packages. Each driver package should have a JSON
        metadata file and associated INF files.

    .PARAMETER PassThru
        When specified, returns a detailed PSCustomObject with installation results including success status,
        driver count, errors, and installed driver details. Without this switch, the function returns null
        and only displays informational messages.

    .EXAMPLE
        PS C:\> Install-PrinterDrivers -SourcePath "C:\DriversExport"
        Installs all printer drivers from C:\DriversExport (no return value)

    .EXAMPLE
        PS C:\> Install-PrinterDrivers -SourcePath "D:\PrinterBackup" -Verbose
        Installs drivers with verbose output showing detailed progress

    .EXAMPLE
        PS C:\> $result = Install-PrinterDrivers -SourcePath "D:\Backup" -PassThru
        PS C:\> if ($result.Success) { Write-Information "Successfully installed $($result.DriversInstalled) drivers" }
        Installs drivers and checks the result

    .EXAMPLE
        PS C:\> $result = Install-PrinterDrivers -SourcePath "E:\Drivers" -PassThru
        PS C:\> $result.InstalledDrivers | Format-Table DriverPackage, Status, DriverNames
        Installs drivers and displays a summary table

    .EXAMPLE
        PS C:\> Install-PrinterDrivers -SourcePath "D:\Backup" -InformationAction SilentlyContinue
        Installs drivers without displaying progress messages (silent mode)

    .EXAMPLE
        PS C:\> $result = Install-PrinterDrivers -SourcePath "D:\Backup" -PassThru
        PS C:\> if (-not $result.Success) { $result.Errors | ForEach-Object { Write-Warning $_ } }
        Installs drivers and displays any errors that occurred

    .NOTES
        Function  : Install-PrinterDrivers
        Author    : John Billekens
        CoAuthor  : Claude (Anthropic)
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 1.1

        Requirements:
        - Administrator privileges (required for pnputil.exe and Add-PrinterDriver)
        - Windows PowerShell 5.1 or PowerShell 7+
        - PrintManagement module (typically built-in on Windows)
        - Source directory must contain drivers exported by Export-PrinterDrives
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [switch]$PassThru
    )
    #requires -Module PrintManagement
    #requires -RunAsAdministrator

    try {
        # Validate source path
        if (-not (Test-Path -Path $SourcePath)) {
            throw "Source path does not exist: $SourcePath"
        }

        Write-Verbose "Validating source path: $SourcePath"

        # Get Windows DriverStore path dynamically
        $driverStorePath = Join-Path -Path $env:SystemRoot -ChildPath "System32\DriverStore\FileRepository"

        Write-Information "Scanning for driver packages in: $SourcePath" -InformationAction Continue -Tags "Progress"
        $sourceFiles = Get-ChildItem -Path $SourcePath -Filter *.json -Recurse -ErrorAction Stop |
            Where-Object { $_.Name -match "^.+_.+_.+\.json$" }

        if ($sourceFiles.Count -eq 0) {
            Write-Warning "No driver packages found in $SourcePath"
            if ($PassThru) {
                return [PSCustomObject]@{
                    Success          = $true
                    DriversInstalled = 0
                    TotalDrivers     = 0
                    SourcePath       = $SourcePath
                    InstalledDrivers = @()
                    Errors           = @()
                }
            }
            return $null
        }

        Write-Information "Found $($sourceFiles.Count) driver package(s) to install" -InformationAction Continue -Tags "Progress"

        $installedDrivers = @()
        $errors = @()
        $currentPackage = 0
        $totalPackages = $sourceFiles.Count
        $successfulInstalls = 0

        foreach ($file in $sourceFiles) {
            $currentPackage++
            $percentComplete = [math]::Round(($currentPackage / $totalPackages) * 100)
            Write-Progress -Activity "Installing Printer Drivers" -Status "Processing: $($file.Name) ($currentPackage of $totalPackages)" -PercentComplete $percentComplete

            try {
                Write-Verbose "Reading driver metadata from: $($file.FullName)"
                $jsonContent = Get-Content -Path $file.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

                # Validate JSON structure
                if (-not $jsonContent.InfPath -or -not $jsonContent.InfFileName) {
                    $errorMsg = "Invalid JSON structure in $($file.Name): Missing InfPath or InfFileName"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    continue
                }

                $infPath = Join-Path -Path $file.DirectoryName -ChildPath $jsonContent.InfPath
                $infPath = Join-Path -Path $infPath -ChildPath $jsonContent.InfFileName

                if (-not (Test-Path -Path $infPath)) {
                    $errorMsg = "INF file not found: $infPath"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    continue
                }

                Write-Information "Installing driver package: $($file.BaseName)" -InformationAction Continue -Tags "Progress"
                Write-Verbose "Adding driver package to store from: $infPath"

                # Add driver to driver store using pnputil
                $pnpOutput = & "$env:SystemRoot\System32\pnputil.exe" /add-driver "$infPath" 2>&1

                if ($LASTEXITCODE -ne 0) {
                    $errorMsg = "pnputil.exe failed for $($file.Name) with exit code $LASTEXITCODE"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    continue
                }

                # Parse pnputil output
                try {
                    $totalMatch = [regex]::Match($pnpOutput, "Total driver packages:\s*(\d+)")
                    $totalDriverPackages = if ($totalMatch.Success) { [int]$totalMatch.Groups[1].Value } else { 0 }
                    $addedMatch = [regex]::Match($pnpOutput, "Added driver packages:\s*(\d+)")
                    $addedDriverPackages = if ($addedMatch.Success) { [int]$addedMatch.Groups[1].Value } else { 0 }
                    $addedSuccessfully = $pnpOutput -like "*Driver package added successfully*" -or $pnpOutput -like "*already exists*"

                    Write-Verbose "Total driver packages: $totalDriverPackages, Added driver packages: $addedDriverPackages, Added successfully: $addedSuccessfully"
                } catch {
                    $errorMsg = "Failed to parse pnputil.exe output for $($file.Name): $($_.Exception.Message)"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    continue
                }

                if (-not $addedSuccessfully) {
                    $errorMsg = "Failed to add driver package from $infPath"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    continue
                }

                Write-Verbose "Driver package added successfully to driver store"

                # Check if driver was installed to driver store
                $installedInfPath = Join-Path -Path $driverStorePath -ChildPath $jsonContent.InfPath
                $installedInfPath = Join-Path -Path $installedInfPath -ChildPath $jsonContent.InfFileName

                if (Test-Path -Path $installedInfPath -ErrorAction SilentlyContinue) {
                    Write-Verbose "Driver found in driver store: $installedInfPath"
                    $infPath = $installedInfPath
                } else {
                    Write-Verbose "Using original INF path for driver installation"
                }

                # Install printer drivers
                $driverInstallResults = @()
                $packageHasError = $false

                if ($jsonContent.DriverNames -and $jsonContent.DriverNames.Count -gt 0) {
                    foreach ($driverName in $jsonContent.DriverNames) {
                        try {
                            Write-Verbose "Installing printer driver: $driverName from $infPath"
                            Add-PrinterDriver -Name $driverName -InfPath $infPath -ErrorAction Stop
                            Write-Verbose "Successfully installed printer driver: $driverName"
                            $driverInstallResults += [PSCustomObject]@{
                                DriverName = $driverName
                                Status     = "Success"
                                Error      = $null
                            }
                        } catch {
                            $errorMsg = "Failed to install printer driver '$driverName' from $($file.Name): $($_.Exception.Message)"
                            Write-Warning $errorMsg
                            $errors += $errorMsg
                            $packageHasError = $true
                            $driverInstallResults += [PSCustomObject]@{
                                DriverName = $driverName
                                Status     = "Failed"
                                Error      = $_.Exception.Message
                            }
                        }
                    }
                } else {
                    $errorMsg = "No driver names found in JSON metadata: $($file.Name)"
                    Write-Warning $errorMsg
                    $errors += $errorMsg
                    $packageHasError = $true
                }

                # Track installed driver package
                $installedDrivers += [PSCustomObject]@{
                    DriverPackage   = $file.BaseName
                    SourceFile      = $file.FullName
                    InfPath         = $infPath
                    DriverNames     = $jsonContent.DriverNames
                    Manufacturer    = $jsonContent.Manufacturer
                    Version         = $jsonContent.Version
                    Environment     = $jsonContent.PrinterEnvironment
                    InstallResults  = $driverInstallResults
                    HasErrors       = $packageHasError
                }

                if (-not $packageHasError) {
                    Write-Information "Successfully installed: $($file.BaseName) ($($jsonContent.DriverNames -join ', '))" -InformationAction Continue -Tags "Success"
                    $successfulInstalls++
                } else {
                    Write-Information "Partially installed: $($file.BaseName) (with errors)" -InformationAction Continue -Tags "Warning"
                }

            } catch {
                $errorMsg = "Error processing driver package $($file.Name): $($_.Exception.Message)"
                Write-Error $errorMsg
                $errors += $errorMsg
            }
        }

        Write-Progress -Activity "Installing Printer Drivers" -Completed

        Write-Information "Installation complete: $successfulInstalls of $totalPackages driver packages installed successfully" -InformationAction Continue -Tags "Complete"

        if ($PassThru) {
            Write-Verbose "PassThru specified - returning detailed results object"
            return [PSCustomObject]@{
                Success          = ($errors.Count -eq 0)
                DriversInstalled = $successfulInstalls
                TotalDrivers     = $totalPackages
                SourcePath       = $SourcePath
                InstalledDrivers = $installedDrivers
                Errors           = $errors
            }
        } else {
            Write-Verbose "No PassThru specified - not returning detailed results object"
            return $null
        }

    } catch {
        Write-Error "Critical error during driver installation: $($_.Exception.Message)"
        if ($PassThru) {
            return [PSCustomObject]@{
                Success          = $false
                DriversInstalled = 0
                TotalDrivers     = 0
                SourcePath       = $SourcePath
                InstalledDrivers = @()
                Errors           = @($_.Exception.Message)
            }
        }
        return $null
    }
}
