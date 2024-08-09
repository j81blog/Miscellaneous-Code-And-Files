<#
.SYNOPSIS
    This script performs client detection for Citrix Workspace App and gathers client version metadata.

.DESCRIPTION
    This script is used to detect the client version of Citrix Workspace App and gather metadata related to the version. It supports two parameter sets: "Parameter" and "JSON". The "Parameter" parameter set allows you to specify the parameters directly, while the "JSON" parameter set allows you to load the parameters from a JSON file.

.PARAMETER EnableLogging
    Specifies whether logging should be enabled. By default, logging is disabled.

.PARAMETER LoggingPath
    Specifies the path where the log file should be saved. The default path is the user's temporary folder.

.PARAMETER JSONFilename
    Specifies the path to the JSON file containing the parameters. This parameter is only used when the "JSON" parameter set is selected.

.PARAMETER MessageLogo
    Specifies the path to the logo file. This parameter is used to update the logo file path.

.PARAMETER MessageTextEOL
    Specifies the end-of-life message text.

.PARAMETER MessageTextCVE
    Specifies the CVE (Common Vulnerabilities and Exposures) message text.

.PARAMETER MessageTitle
    Specifies the title of the message.

.PARAMETER RunLocal
    Specifies whether the script should run locally. By default, it runs remotely.
    Don't specify this parameter when running the script in a Citrix Session.

.PARAMETER LogoffOnEOL
    Specifies whether to log off the user when the end-of-life message is displayed.

.PARAMETER LogoffOnCVE
    Specifies whether to log off the user when the CVE message is displayed.

.PARAMETER Test
    Specifies whether the script should run in test mode.
    Do not specify the -Test parameter when presenting the script to the user.

.EXAMPLE
    .\CWACLientDetection.ps1 -EnableLogging -LoggingPath "C:\Logs" -MessageLogo "C:\Logo.png" -MessageTextEOL "Multiline`r`nEnd of life message" -MessageTextCVE "Multiline`r`nCVE message" -MessageTitle "Title" -RunLocal -LogoffOnEOL -LogoffOnCVE -Test
    Runs the script with the specified parameters in test mode, running locally and logging off the user on EOL and CVE messages.

.EXAMPLE
    @params = @{
        "EnableLogging" = $true
        "LoggingPath" = "<PathTo>\Logs"
        "MessageLogo" = "<PathTo>\Logo.png"
        "MessageTextEOL" = @"
    Multiline
    End of life message
    "@
        "MessageTextCVE" = @"
    Multiline
    CVE message
    "@
        "MessageTitle" = "Title"
        "RunLocal" = $false
        "LogoffOnEOL" = $true
        "LogoffOnCVE" = $true
    }
    .\CWACLientDetection.ps1 @params [-Test]
    Runs the script with the specified parameters while using splatting, running locally and logging off the user on EOL and CVE messages.
    You can optionally use the -Test parameter to run the script in test mode.

.EXAMPLE
    .\CWACLientDetection.ps1 -JSONFilename "C:\CWACLientDetection.json" [-Test]
    Runs the script using the parameters loaded from the specified JSON file.
    You can optionally use the -Test parameter to run the script in test mode.

.NOTES
    File Name      : CWACLientDetection.ps1
    Author         : John Billekens Consultancy
    Prerequisite   : PowerShell V2.0
    Version        : 1.2
    Copyright      : Copyright (c) 2024 John Billekens Consultancy

#>
[CmdletBinding(DefaultParameterSetName = "Parameter")]
param (
    [Parameter(ParameterSetName = "Parameter")]
    [Parameter(ParameterSetName = "JSON")]
    [Switch]$EnableLogging,

    [Parameter(ParameterSetName = "JSON")]
    [Parameter(ParameterSetName = "Parameter")]
    [String]$LoggingPath = "$Env:TEMP",

    [Parameter(ParameterSetName = "JSON")]
    [ValidateNotNullOrEmpty()]
    [String]$JSONFilename,

    [Parameter(ParameterSetName = "Parameter")]
    [String]$MessageLogo,

    [Parameter(ParameterSetName = "Parameter")]
    [ValidateNotNullOrEmpty()]
    [String]$MessageTextEOL,

    [Parameter(ParameterSetName = "Parameter")]
    [ValidateNotNullOrEmpty()]
    [String]$MessageTextCVE,

    [Parameter(ParameterSetName = "Parameter")]
    [ValidateNotNullOrEmpty()]
    [String]$MessageTitle,

    [Parameter(ParameterSetName = "JSON")]
    [Parameter(ParameterSetName = "Parameter")]
    [Switch]$RunLocal,

    [Parameter(ParameterSetName = "Parameter")]
    [Switch]$LogoffOnEOL,

    [Parameter(ParameterSetName = "Parameter")]
    [Switch]$LogoffOnCVE,

    [Parameter(ParameterSetName = "JSON")]
    [Parameter(ParameterSetName = "Parameter")]
    [Switch]$Test

)

#region Checkx86orx64

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Write-Warning "changing from 32bit to 64bit PowerShell..."
    $powershell = $PSHOME.tolower().replace("syswow64", "sysnative").replace("system32", "sysnative")

    if ($myInvocation.Line) {
        & "$powershell\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass $myInvocation.Line
    } else {
        & "$powershell\powershell.exe" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -file "$($myInvocation.InvocationName)" $args
    }
    exit $lastexitcode
}

#end region Checkx86orx64

if ($Test -eq $true) {
    Write-Warning "Test mode is enabled"
    $VerbosePreference = "Continue"
}

#region Logging

if ([bool]$EnableLogging -eq $true) {
    try {
        $logFile = Join-Path -Path $LoggingPath -ChildPath "CWACLientDetectionScript.log"
        Start-Transcript -Path $logFile -Force -Append

    } catch {
        Write-Warning "Failed to start logging, $($_.Exception.Message)"
    }
}

#end region Logging

#region Variables

$version = "1.1"
if ($PSCmdlet.ParameterSetName -eq "JSON") {
    if (Test-Path -Path "$JSONFilename") {
        try {
            $jsonParams = Get-Content -Path "$JSONFilename" | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to load the JSON file, not formatted properly? Error: $($_.Exception.Message)"
            Exit 1
        }
        Write-Verbose "JSON file loaded, using the parameters from the JSON file"
        $MessageLogo = $jsonParams.MessageLogo
        $MessageTextEOL = $jsonParams.MessageTextEOL
        $MessageTextCVE = $jsonParams.MessageTextCVE
        $MessageTitle = $jsonParams.MessageTitle
        try { if ($jsonParams.LogoffOnEOL -is [bool]) { $LogoffOnEOL = $jsonParams.LogoffOnEOL } else { $LogoffOnEOL = $false } } catch { $LogoffOnEOL = $false }
        Write-Verbose "LogoffOnEOL: $LogoffOnEOL"
        try { if ($jsonParams.LogoffOnCVE -is [bool]) { $LogoffOnCVE = $jsonParams.LogoffOnCVE } else { $LogoffOnCVE = $false } } catch { $LogoffOnCVE = $false }
        Write-Verbose "LogoffOnCVE: $LogoffOnCVE"
        try { if ($jsonParams.RunLocal -is [bool]) { $RunLocal = $jsonParams.RunLocal } else { $RunLocal = $false } } catch { $RunLocal = $false }
        Write-Verbose "RunLocal: $RunLocal"
    } else {
        Write-Warning "The JSON file does not exist"
        Exit 1
    }

}
if (-Not [String]::IsNullOrEmpty($MessageLogo)) {
    if ($MessageLogo -like ".\*") {
        $MessageLogo = "$($MessageLogo)".Replace(".\", "$($PSScriptRoot)\")
        Write-Verbose "Logo file path updated, new path: $MessageLogo"
    }
    if (Test-Path -Path $MessageLogo) {
        Write-Verbose "Logo file exists, using the logo file"
    } else {
        Write-Warning "The logo file does not exist"
        $MessageLogo = $null
    }
}

$platform = "N/A"

#end region Variables

#region GatherMetadata

#region functions
function Test-CWAWindowsVersion {
    [CmdletBinding()]
    param (
        [Version]$Version
    )
    $isLtsrVersion = $false
    $isCveImpacted = $false
    $isEOL = $false
    $cves = @()
    #CVE-2021-22907
    #https://support.citrix.com/article/CTX307794'
    #Solved
    #Citrix Workspace App 2105 and later >=19.13.0 <21.5.0
    #Citrix Workspace App 1912 LTSR CU4 and later cumulative updates >=19.12.0 <19.12.4000

    #CVE-2023-24483
    #https://support.citrix.com/article/CTX477616
    #Affected:
    #Citrix Workspace App versions before 2212 >=22.04.0 <22.12.0
    #Citrix Workspace App 2203 LTSR before CU2 >=19.13.0 <22.3.2000
    #Citrix Virtual Apps and Desktops 1912 LTSR before CU6  (19.12.6000.9)

    #CVE-2023-24484 & CVE-2023-24485
    #https://support.citrix.com/article/CTX477617
    #Affected:
    #Citrix Workspace App versions before 2212 >=22.04.0 <22.12.0
    #Citrix Workspace App 2203 LTSR before CU2 >=19.13.0 <22.3.2000
    #Citrix Workspace App 1912 LTSR before CU7 Hotfix 2 <19.12.7002

    #CVE-2020-13884 & CVE-2020-13885
    #https://support.citrix.com/article/CTX275460
    #Citrix Workspace App for Windows versions before 1912 < 19.12.0
    #Cirtrix Receiver 4.9 Cumulative Update 9 or later < 4.9.9002

    #CVE-2024-6286
    #https://support.citrix.com/article/CTX678036
    #Affected:
    #Citrix Workspace app for Windows versions before 2203.1 LTSR CU6 Hotfix 2 <22.03.6002.6116
    #Citrix Workspace app for Windows versions before 2403.1 >=24.03.0 <24.3.1.97
    #Citrix Workspace app for Windows versions before 2402 LTSR >=22.04.0 <24.2.0.172

    switch ($version) {
        { $_ -ge [Version]"19.13.0" -and $_ -lt [Version]"21.5.0" } {
            # Citrix Workspace App versions before 2105 - CTX307794
            $isCveImpacted = $true
            $cves += "CVE-2021-22907"
        }
        { $_ -lt [Version]"19.12.4000" } {
            # Citrix Workspace App versions before 1912 LTSR CU4 - CTX307794
            $isCveImpacted = $true
            $cves += "CVE-2021-22907"
        }
        { $_ -ge [Version]"22.04.0" -and $_ -lt [Version]"22.12.0.48" } {
            # Citrix Workspace App versions before 2212 - CTX477616 / CTX477617
            $isCveImpacted = $true
            $cves += "CVE-2023-24483"
            $cves += "CVE-2023-24484"
            $cves += "CVE-2023-24485"
        }
        { $_ -ge [Version]"19.13.0" -and $_ -lt [Version]"22.03.2000" } {
            # Citrix Workspace App 2203 LTSR before CU2 - CTX477616 / CTX477617
            $isCveImpacted = $true
            $cves += "CVE-2023-24483"
            $cves += "CVE-2023-24484"
            $cves += "CVE-2023-24485"
        }
        { $_ -lt [Version]"19.12.6000.9" } {
            # Citrix Virtual Apps and Desktops 1912 LTSR before CU6  (19.12.6000.9) - CTX477616
            $isCveImpacted = $true
            $cves += "CVE-2023-24483"
        }
        { $_ -lt [Version]"19.12.7002" } {
            # Citrix Workspace App 1912 LTSR before CU7 Hotfix 2 (19.12.7002) - CTX477617
            $isCveImpacted = $true
            $cves += "CVE-2023-24484"
            $cves += "CVE-2023-24485"
        }
        { $_ -lt [Version]"19.12.0" } {
            # These vulnerabilities affect supported versions of Citrix Workspace app for Windows before 1912 and supported versions of Citrix Receiver for Windows. - CTX275460
            $isCveImpacted = $true
            $cves += "CVE-2020-13884"
            $cves += "CVE-2020-13885"
        }
        { $_ -lt [Version]"22.03.6002.6116" } {
            # Citrix Workspace app for Windows versions before 2203.1 LTSR CU6 Hotfix 2 - CTX678036
            $isCveImpacted = $true
            $cves += "CVE-2024-6286"
        }
        { $_ -ge [Version]"24.03.0" -and $_ -lt [Version]"24.3.1.97" } {
            # Citrix Workspace app for Windows versions before 2403.1 - CTX678036
            $isCveImpacted = $true
            $cves += "CVE-2024-6286"
        }
        { $_ -ge [Version]"22.04.0" -and $_ -lt [Version]"24.2.0.172" } {
            # Citrix Workspace app for Windows versions before 2402 LTSR - CTX678036
            $isCveImpacted = $true
            $cves += "CVE-2024-6286"
        }
        { $_ -le [Version]"19.11.0" -or $_ -le [Version]"19.12.7002" } {
            $isCveImpacted = $true
        }
        { $_ -gt [Version]"22.03.0" -and $_ -lt [Version]"22.4.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"19.12.0" -and $_ -lt [Version]"19.13.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"4.9.0" -and $_ -lt [Version]"4.10.0" } {
            $isLtsrVersion = $true
        }
        { $_ -ge [Version]"24.2.0" -and $_ -lt [Version]"24.3.0" } {
            $isLtsrVersion = $true
        }
        #https://www.citrix.com/support/product-lifecycle/workspace-app.html
        { $_ -eq [Version]"23.11.0.132" -and (Get-Date) -le [DateTime]"2025-6-25" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.9.1.104" -and (Get-Date) -le [DateTime]"2025-5-2" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.9.0.99" -and (Get-Date) -le [DateTime]"2025-4-10" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.7.1.18" -and (Get-Date) -le [DateTime]"2025-2-12" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.7.0.15" -and (Get-Date) -le [DateTime]"2025-2-12" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.5.1.83" -and (Get-Date) -le [DateTime]"2025-1-3" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.3.0.55" -and (Get-Date) -le [DateTime]"2024-9-29" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.2.0.38" -and (Get-Date) -le [DateTime]"2024-8-16" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"22.12.0.48" -and (Get-Date) -le [DateTime]"2024-7-23" } {
            $isEOL = $true
        }
        { $_ -le [Version]"22.10.5.14" } {
            $isEOL = $true
        }
    }
    $cves = $cves | Sort-Object -Unique
    $result = [PSCustomObject]@{
        Version         = $version
        Evaluated       = $true
        IsLTSR          = $isLtsrVersion
        IsisCveImpacted = $isCveImpacted
        IsEOL           = $isEOL
        UpdateInfo      = $null
        CVEs            = $cves
    }
    try {
        $latestVersion = Get-LatestCWAWindowsVersionInfo
        if ($isLtsrVersion -eq $false) {
            $latestVersion = $latestVersion | Where-Object { $_.Stream -like "Current" }
        }
        $result.UpdateInfo = $latestVersion
    } catch {
        Write-Warning "Failed to get the latest version information, $($_.Exception.Message)"
        $result.UpdateInfo = $null
    }
    Write-Output $result
}

function Test-CWALinuxVersion {
    [CmdletBinding()]
    param (
        [Version]$Version
    )
    $isLtsrVersion = $false
    $isCveImpacted = $false
    $isEOL = $false
    $cves = @()
    #CVE-2023-24486
    #https://support.citrix.com/article/CTX477618
    #Affected:
    #Citrix Workspace App versions before 2302 <23.02.0
    switch ($version) {
        { $_ -lt [Version]"23.02.0" } {
            # Citrix Workspace App versions before 2302 - CTX477618
            $isCveImpacted = $true
            $cves += "CVE-2023-24486"
        }
        { $_ -lt [Version]"22.9" -and (Get-Date) -le [DateTime]"2024-3-29" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"22.11" -and (Get-Date) -le [DateTime]"2024-5-08" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"22.12" -and (Get-Date) -le [DateTime]"2024-6-1" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.2" -and (Get-Date) -le [DateTime]"2024-8-1" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.3" -and (Get-Date) -le [DateTime]"2024-9-23" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.5" -and (Get-Date) -le [DateTime]"2024-11-30" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.7" -and (Get-Date) -le [DateTime]"2025-1-6" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.9" -and (Get-Date) -le [DateTime]"2025-4-28" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.11" -and (Get-Date) -le [DateTime]"2025-7-13" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"24.2" -and (Get-Date) -le [DateTime]"2025-9-7" } {
            $isEOL = $true
        }
        { $_ -gt [Version]"22.03.0" -and $_ -lt [Version]"22.4.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"19.12.0" -and $_ -lt [Version]"19.13.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"4.9.0" -and $_ -lt [Version]"4.10.0" } {
            $isLtsrVersion = $true
        }
        { $_ -ge [Version]"24.2.0" -and $_ -lt [Version]"24.3.0" } {
            $isLtsrVersion = $true
        }
    }
    $cves = $cves | Sort-Object -Unique
    $result = [PSCustomObject]@{
        Version         = $version
        Evaluated       = $true
        IsLTSR          = $isLtsrVersion
        IsisCveImpacted = $isCveImpacted
        IsEOL           = $isEOL
        UpdateInfo      = $null
        CVEs            = $cves
    }
    Write-Output $result
}

function Test-CWAMacVersion {
    [CmdletBinding()]
    param (
        [Version]$Version
    )
    $isLtsrVersion = $false
    $isCveImpacted = $false
    $isEOL = $false
    $cves = @()
    #CVE-2024-5027
    #https://support.citrix.com/article/CTX675851
    #Affected:
    #Citrix Workspace app for Mac before 2402.10 <24.02.10
    switch ($version) {
        { $_ -lt [Version]"24.02.10" } {
            # Citrix Workspace app for Mac before 2402.10 - CTX675851
            $isCveImpacted = $true
            $cves += "CVE-2024-5027"
        }
        { $_ -gt [Version]"22.03.0" -and $_ -lt [Version]"22.4.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"19.12.0" -and $_ -lt [Version]"19.13.0" } {
            $isLtsrVersion = $true
        }
        { $_ -gt [Version]"4.9.0" -and $_ -lt [Version]"4.10.0" } {
            $isLtsrVersion = $true
        }
        { $_ -ge [Version]"24.2.0" -and $_ -lt [Version]"24.3.0" } {
            $isLtsrVersion = $true
        }
        { $_ -le [Version]"24.02.0.78" -and (Get-Date) -le [DateTime]"2025-10-11" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.1.0.67" -and (Get-Date) -le [DateTime]"2025-6-21" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.09.0.4" -and (Get-Date) -le [DateTime]"2025-3-27" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.08.0.57" -and (Get-Date) -le [DateTime]"2025-3-15" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.07.6.64" -and (Get-Date) -le [DateTime]"2025-1-26" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.06.0.3" -and (Get-Date) -le [DateTime]"2024-12-22" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.05.0.36" -and (Get-Date) -le [DateTime]"2024-11-29" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.04.0.36" -and (Get-Date) -le [DateTime]"2024-10-13" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.01.1.60" -and (Get-Date) -le [DateTime]"2024-9-24" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.01.0.53" -and (Get-Date) -le [DateTime]"2024-7-12" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.01.0.53" } {
            $isEOL = $true
        }
    }
    $cves = $cves | Sort-Object -Unique
    $result = [PSCustomObject]@{
        Version         = $version
        Evaluated       = $true
        IsLTSR          = $isLtsrVersion
        IsisCveImpacted = $isCveImpacted
        IsEOL           = $isEOL
        UpdateInfo      = $null
        CVEs            = $cves
    }
    Write-Output $result
}

function Get-LatestCWAWindowsVersionInfo {
    [CmdletBinding()]
    param ()

    $Uri = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod/catalog_win.xml"
    $result = Get-LatestCWAVersionInfo -Uri $Uri
    Write-Output $result
}

function Get-LatestCWAMacOSVersionInfo {
    [CmdletBinding()]
    param ()

    $Uri = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod/catalog_macos.xml"
    $result = Get-LatestCWAVersionInfo -Uri $Uri
    Write-Output $result
}

function Get-LatestCWAVersionInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [string]$UserAgent = "CitrixReceiver/19.7.0.15 WinOS/10.0.18362",

        [string]$DownloadUri = "https://downloadplugins.citrix.com/ReceiverUpdates/Prod"
    )

    $params = @{
        Uri                = $Uri
        ContentType        = "application/json; charset=utf-8"
        DisableKeepAlive   = $true
        MaximumRedirection = 2
        Method             = "Get"
        UseBasicParsing    = $true
        UserAgent          = $UserAgent
    }
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    $Response = Invoke-RestMethod @params
    if ($null -ne $Response) {

        # Filter the update feed for just the installers we want
        $Installers = $Response.Catalog.Installers | Where-Object { $_.name -eq 'Receiver' } | Select-Object -ExpandProperty 'Installer'

        # Walk through each node to output details
        foreach ($Installer in $Installers) {
            $PSObject = [PSCustomObject]@{
                Version = $Installer.Version
                Title   = $($Installer.ShortDescription -replace ":", "")
                Size    = $(if ($Installer.Size) { $Installer.Size } else { "Unknown" })
                Hash    = $Installer.Hash
                Date    = $(try { ([System.DateTime]::ParseExact(($Installer.StartDate), 'yyyy-MM-dd', [System.Globalization.CultureInfo]::CurrentUICulture.DateTimeFormat)).ToShortDateString() } catch { $Installer.StartDate })
                Stream  = $Installer.Stream
                URI     = "$($DownloadUri)$($Installer.DownloadURL)"
            }
            Write-Output -InputObject $PSObject
        }
    }

}

function Get-LocalWindowsCWAVersion {
    [CmdletBinding()]
    param ()

    $regPaths = @(
        'HKLM:\SOFTWARE\Citrix\InstallDetect',
        'HKLM:\SOFTWARE\WOW6432Node\Citrix\InstallDetect'
    )
    ForEach ($regPath in $regPaths) {
        if (Test-Path -Path $regPath) {
            $version = Get-ChildItem -Path $regPath | Get-ItemProperty | Select-Object -Property DisplayVersion | Select-Object -ExpandProperty DisplayVersion
            break
        }
    }
    return $version
}

function Invoke-LogoffSession {
    [CmdletBinding()]
    param ()

    try {
        Write-Verbose "Logoff is enabled, logging off the user"
        if (Test-Path -Path "C:\Windows\System32\logoff.exe") {
            & "C:\Windows\System32\logoff.exe"
        } else {
            & "C:\Windows\System32\shutdown.exe" -l -f
        }
    } catch {
        Write-Warning "Failed to log off the user, $($_.Exception.Message)"
    }
}

function Show-MessageToUser {
    [CmdletBinding()]
    param (
        [string]$Message,

        [string]$Title = "Citrix Workspace App version check",

        [string]$Logo = $Script:MessageLogo

    )
    Add-Type -AssemblyName PresentationFramework

    Write-Verbose "Create a WPF window"
    $window = New-Object -TypeName System.Windows.Window
    $window.Title = $Title
    $window.SizeToContent = "WidthAndHeight"
    $window.WindowStartupLocation = "CenterScreen"
    $window.Topmost = $true  # Set the window to always stay on top

    $window.ResizeMode = "NoResize"  # Remove maximize and minimize buttons
    $window.WindowStyle = "ToolWindow"  # Remove the icon from the title bar


    Write-Verbose "Create a stack panel to hold the message and button"
    $stackPanel = New-Object -TypeName System.Windows.Controls.StackPanel
    $stackPanel.Margin = New-Object -TypeName System.Windows.Thickness -ArgumentList 10
    $window.Content = $stackPanel

    if (-Not [String]::IsNullOrEmpty($Logo) -and (Test-Path -Path $Logo)) {
        Write-Verbose "Create an image control for the logo"
        $image = New-Object -TypeName System.Windows.Controls.Image
        $image.Source = New-Object -TypeName System.Windows.Media.Imaging.BitmapImage -ArgumentList $Logo
        $image.Width = 200
        $image.Height = 200
        $image.HorizontalAlignment = "Center"
        $stackPanel.Children.Add($image) | Out-Null
    }

    Write-Verbose "Create a text block to display the message"
    $textBlock = New-Object -TypeName System.Windows.Controls.TextBlock
    $textBlock.Text = $message
    $textBlock.TextAlignment = "Center"
    $textBlock.TextWrapping = "Wrap"
    $stackPanel.Children.Add($textBlock) | Out-Null

    Write-Verbose "Create an OK button"
    $button = New-Object -TypeName System.Windows.Controls.Button
    $button.Content = "OK"
    $button.Margin = New-Object -TypeName System.Windows.Thickness -ArgumentList 0, 0, 0, 0
    $button.Width = 60
    $button.HorizontalAlignment = "Center"
    $button.Add_Click({
            $window.Close()
        })
    $stackPanel.Children.Add($button) | Out-Null

    Write-Verbose "Show the window"
    $window.ShowDialog() | Out-Null
    return $true
}

#end region functions
$isWindowsOS = $false
try {
    if ($isWindows -eq $true) {
        $isWindowsOS = $true
    } elseif (([Environment]::OSVersion).VersionString -like "*windows*") {
        $isWindowsOS = $true
    }
} catch {
    $isWindowsOS = $false
}
if ($RunLocal -eq $true -and $Test -eq $false -and $isWindowsOS -eq $true) {
    $clientVersion = Get-LocalWindowsCWAVersion
    $platform = "Windows"
    $result = Test-CWAWindowsVersion -Version $clientVersion
    $hostText = @"
Citrix Workspace App version check:
Platform`t : $platform
Client Version`t : $($result.Version)
Evaluated`t : $($result.Evaluated)
Is LTSR`t`t : $($result.IsLTSR)
Is CVE Impacted`t : $($result.IsisCveImpacted)
Is EOL`t`t : $($result.IsEOL)
CVE's impacted`t : $($result.CVEs -join ', ')
"@

    Write-Information -MessageData $hostText -InformationAction Continue
    try { Write-EventLog -LogName Application -Source "Application" -EntryType Information -EventId 219 -Message $hostText -ErrorAction SilentlyContinue } catch { <# Do Nothing #> }
    # 219 = 67+87+65 => C (67) W (87) A (65) => https://cryptii.com/pipes/text-decimal
    if ($result.Evaluated -eq $true -and $result.IsEOL -eq $true) {
        $message = ("$MessageTextEOL").Replace("##platform##", $platform)
        $showMessage = $true
    }

    if ($result.Evaluated -eq $true -and $result.IsisCveImpacted -eq $true) {
        $message = ("$MessageTextCVE").Replace("##platform##", $platform)
        $showMessage = $true
    }

    if ($showMessage -eq $true) {
        Write-Verbose "Message: $message"
        if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and ($LogoffOnEOL -eq $true -or $LogoffOnCVE -eq $true)) {
            Write-Verbose "Logoff is enabled, logging off the user"
            Invoke-LogoffSession
        }
    } else {
        Write-Verbose "A supported version ($($result.Version)) was detected for $($platform)"
    }
} elseif ((Test-Path -Path "HKLM:\SOFTWARE\Citrix\Ica\Session") -and ($Test -eq $false)) {
    try {
        $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        $connectionDetails = Get-ItemProperty -Path "HKLM:\SOFTWARE\Citrix\Ica\Session\$($sessionId)\Connection"
        $clientVersion = [Version]$connectionDetails.ClientVersion
        $clientPlatform = $connectionDetails.ClientProductID
    } catch {
        $clientVersion = "Unknown"
        $clientPlatform = "0"
    }
    Write-Verbose "Client PlatformID : $clientPlatform"
    Write-Verbose "Client Version    : $clientVersion"
    #end region GatherMetadata

    #region basics

    $result = [PSCustomObject]@{
        Version         = $clientVersion
        Evaluated       = $false
        IsLTSR          = $false
        IsisCveImpacted = $false
        IsEOL           = $false
    }

    #end region basics

    switch ([String]$clientPlatform) {
        "1" {
            $platform = "Windows"
            $result = Test-CWAWindowsVersion -Version $clientVersion
        }
        "81" {
            $platform = "Linux"
            $result = Test-CWALinuxVersion -Version $clientVersion
        }
        "82" {
            $platform = "Mac OS"
            $result = Test-CWAMacVersion -Version $clientVersion
        }
        "83" {
            $platform = "iOS"
        }
        "84" {
            $platform = "Android"
        }
        "85" {
            $platform = "Blackberry"
        }
        "86" {
            $platform = "Windows Phone 8/WinRT"
        }
        "87" {
            $platform = "Windows Mobile"
        }
        "88" {
            $platform = "Blackberry Playbook"
        }
        "257" {
            $platform = "HTML5"
        }
        default {
            $platform = "N/A"
        }    # Unknown platform
    }
    $hostText = @"
Citrix Workspace App version check:
Platform`t : $platform
Client Version`t : $($result.Version)
Evaluated`t : $($result.Evaluated)
Is LTSR`t`t : $($result.IsLTSR)
Is CVE Impacted`t : $($result.IsisCveImpacted)
Is EOL`t`t : $($result.IsEOL)
CVE's impacted`t : $($result.CVEs -join ', ')
"@

    Write-Information -MessageData $hostText -InformationAction Continue
    try { Write-EventLog -LogName Application -Source "Application" -EntryType Information -EventId 219 -Message $hostText -ErrorAction SilentlyContinue } catch { <# Do Nothing #> }
    # 219 = 67+87+65 => C (67) W (87) A (65) => https://cryptii.com/pipes/text-decimal
    if ($result.Evaluated -eq $true -and $result.IsEOL -eq $true) {
        $message = ("$MessageTextEOL").Replace("##platform##", $platform)
        $showMessage = $true
    }

    if ($result.Evaluated -eq $true -and $result.IsisCveImpacted -eq $true) {
        $message = ("$MessageTextCVE").Replace("##platform##", $platform)
        $showMessage = $true
    }

    if ($showMessage -eq $true) {
        Write-Verbose "Message: $message"
        if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and ($LogoffOnEOL -eq $true -or $LogoffOnCVE -eq $true)) {
            Write-Verbose "Logoff is enabled, logging off the user"
            Invoke-LogoffSession
        }
    } else {
        Write-Verbose "A supported version ($($result.Version)) was detected for $($platform)"
    }
} elseif ([bool]$Test -eq $true) {
    Write-Verbose "Running in test mode"
    $platform = "!!TEST - v$version - EOL!!"
    $message = ("$MessageTextEOL").Replace("##platform##", $platform)
    Write-Verbose "Title: $MessageTitle"
    Write-Verbose "Message: $message"
    if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and ($LogoffOnEOL -eq $true -or $LogoffOnCVE -eq $true)) {
        Write-Verbose "Logoff is enabled, logging off the user"
        Show-MessageToUser -Message "Your session would have been logged off now`r`n$platform" -Title "Session Logoff [Test]"
    }
    $platform = "!!TEST - v$version - CVE!!"
    $message = ("$MessageTextCVE").Replace("##platform##", $platform)
    Write-Verbose "Title: $MessageTitle"
    Write-Verbose "Message: $message"
    if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and ($LogoffOnEOL -eq $true -or $LogoffOnCVE -eq $true)) {
        Write-Verbose "Logoff is enabled, logging off the user"
        Show-MessageToUser -Message "Your session would have been logged off now`r`n$platform" -Title "Session Logoff [Test]"
    }
} else {
    Write-Warning "The script is not running in a Citrix environment"
}

#region Logging

if ([bool]$EnableLogging -eq $true) {
    try {
        Stop-Transcript
    } catch {
        Write-Warning "Failed to stop logging, $($_.Exception.Message)"
    }
}

#end region Logging

if ($Test -eq $true) {
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# SIG # Begin signature block
# MIIndQYJKoZIhvcNAQcCoIInZjCCJ2ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBaXXXcYTfp9zum
# C/sAHxsEh+IJ4a56Yl7GbxinVyBmpaCCICkwggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggZFMIIELaADAgECAhAIMk+dt9qRb2Pk
# 8qM8Xl1RMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNp
# Z25pbmcgMjAyMSBDQTAeFw0yNDA0MDQxNDA0MjRaFw0yNzA0MDQxNDA0MjNaMGsx
# CzAJBgNVBAYTAk5MMRIwEAYDVQQHDAlTY2hpam5kZWwxIzAhBgNVBAoMGkpvaG4g
# QmlsbGVrZW5zIENvbnN1bHRhbmN5MSMwIQYDVQQDDBpKb2huIEJpbGxla2VucyBD
# b25zdWx0YW5jeTCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAMslntDb
# SQwHZXwFhmibivbnd0Qfn6sqe/6fos3pKzKxEsR907RkDMet2x6RRg3eJkiIr3TF
# PwqBooyXXgK3zxxpyhGOcuIqyM9J28DVf4kUyZHsjGO/8HFjrr3K1hABNUszP0o7
# H3o6J31eqV1UmCXYhQlNoW9FOmRC1amlquBmh7w4EKYEytqdmdOBavAD5Xq4vLPx
# NP6kyA+B2YTtk/xM27TghtbwFGKnu9Vwnm7dFcpLxans4ONt2OxDQOMA5NwgcUv/
# YTpjhq9qoz6ivG55NRJGNvUXsM3w2o7dR6Xh4MuEGrTSrOWGg2A5EcLH1XqQtkF5
# cZnAPM8W/9HUp8ggornWnFVQ9/6Mga+ermy5wy5XrmQpN+x3u6tit7xlHk1Hc+4X
# Y4a4ie3BPXG2PhJhmZAn4ebNSBwNHh8z7WTT9X9OFERepGSytZVeEP7hgyptSLcu
# hpwWeR4QdBb7dV++4p3PsAUQVHFpwkSbrRTv4EiJ0Lcz9P1HPGFoHiFAQQIDAQAB
# o4IBeDCCAXQwDAYDVR0TAQH/BAIwADA9BgNVHR8ENjA0MDKgMKAuhixodHRwOi8v
# Y2NzY2EyMDIxLmNybC5jZXJ0dW0ucGwvY2NzY2EyMDIxLmNybDBzBggrBgEFBQcB
# AQRnMGUwLAYIKwYBBQUHMAGGIGh0dHA6Ly9jY3NjYTIwMjEub2NzcC1jZXJ0dW0u
# Y29tMDUGCCsGAQUFBzAChilodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY2Nz
# Y2EyMDIxLmNlcjAfBgNVHSMEGDAWgBTddF1MANt7n6B0yrFu9zzAMsBwzTAdBgNV
# HQ4EFgQUO6KtBpOBgmrlANVAnyiQC6W6lJwwSwYDVR0gBEQwQjAIBgZngQwBBAEw
# NgYLKoRoAYb2dwIFAQQwJzAlBggrBgEFBQcCARYZaHR0cHM6Ly93d3cuY2VydHVt
# LnBsL0NQUzATBgNVHSUEDDAKBggrBgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwDQYJ
# KoZIhvcNAQELBQADggIBAEQsN8wgPMdWVkwHPPTN+jKpdns5AKVFjcn00psf2NGV
# VgWWNQBIQc9lEuTBWb54IK6Ga3hxQRZfnPNo5HGl73YLmFgdFQrFzZ1lnaMdIcyh
# 8LTWv6+XNWfoyCM9wCp4zMIDPOs8LKSMQqA/wRgqiACWnOS4a6fyd5GUIAm4Cuap
# tpFYr90l4Dn/wAdXOdY32UhgzmSuxpUbhD8gVJUaBNVmQaRqeU8y49MxiVrUKJXd
# e1BCrtR9awXbqembc7Nqvmi60tYKlD27hlpKtj6eGPjkht0hHEsgzU0Fxw7ZJghY
# G2wXfpF2ziN893ak9Mi/1dmCNmorGOnybKYfT6ff6YTCDDNkod4egcMZdOSv+/Qv
# +HAeIgEvrxE9QsGlzTwbRtbm6gwYYcVBs/SsVUdBn/TSB35MMxRhHE5iC3aUTkDb
# ceo/XP3uFhVL4g2JZHpFfCSu2TQrrzRn2sn07jfMvzeHArCOJgBW1gPqR3WrJ4hU
# xL06Rbg1gs9tU5HGGz9KNQMfQFQ70Wz7UIhezGcFcRfkIfSkMmQYYpsc7rfzj+z0
# ThfDVzzJr2dMOFsMlfj1T6l22GBq9XQx0A4lcc5Fl9pRxbOuHHWFqIBD/BCEhwni
# OCySzqENd2N+oz8znKooSISStnkNaYXt6xblJF2dx9Dn89FK7d1IquNxOwt0tI5d
# MIIGlTCCBH2gAwIBAgIQCcXM+LtmfXE3qsFZgAbLMTANBgkqhkiG9w0BAQwFADBW
# MQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwHhcNMjMxMTAy
# MDgzMjIzWhcNMzQxMDMwMDgzMjIzWjBQMQswCQYDVQQGEwJQTDEhMB8GA1UECgwY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0
# YW1wIDIwMjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC5Frrqxud9
# kjaqgkAo85Iyt6ecN343OWPztNOFkORvsc6ukhucOOQQ+szxH0jsi3ARjBwG1b9o
# QwnDx1COOkOpwm2HzY2zxtJe2X2qC+H8DMt4+nUNAYFuMEMjReq5ptDTI3JidDEb
# gcxKdr2azfCwmJ3FpqGpKr1LbtCD2Y7iLrwZOxODkdVYKEyJL0UPJ2A18JgNR54+
# CZ0/pVfCfbOEZag65oyU3A33ZY88h5mhzn9WIPF/qLR5qt9HKe9u8Y+uMgz8MKQa
# gH/ajWG/uYcqeQK28AS3Eh5AcSwl4xFfwHGaFwExxBWSXLZRGUbn9aFdirSZKKde
# 20p1COlmZkxImJY+bxQYSgw5nEM0jPg6rePD+0IQQc4APK6dSHAOQS3QvBJrfzTW
# lCQokGtOvxcNIs5cOvaANmTcGcLgkH0eHgMBpLFlcyzE0QkY8Heh+xltZFEiAvK5
# gbn8CHs8oo9o0/JjLqdWYLrW4HnES43/NC1/sOaCVmtslTaFoW/WRRbtJaRrK/03
# jFjrN921dCntRRinB/Ew3MQ1kxPN604WCMeLvAOpT3F5KbBXoPDrMoW9OGTYnYqv
# 88A6hTbVFRs+Ei8UJjk4IlfOknHWduimRKQ4LYDY1GDSA33YUZ/c3Pootanc2iWP
# Navjy/ieDYIdH8XVbRfWqchnDpTE+0NFcwIDAQABo4IBYzCCAV8wDAYDVR0TAQH/
# BAIwADAdBgNVHQ4EFgQUx2k8Lua941lH/xkSwdk06EHP448wHwYDVR0jBBgwFoAU
# vlQCL79AbHNDzqwJJU6eQ0Qa7uAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMDMGA1UdHwQsMCowKKAmoCSGImh0dHA6Ly9jcmwuY2VydHVt
# LnBsL2N0c2NhMjAyMS5jcmwwbwYIKwYBBQUHAQEEYzBhMCgGCCsGAQUFBzABhhxo
# dHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRwOi8v
# cmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjBBBgNVHSAEOjA4MDYG
# CyqEaAGG9ncCBQELMCcwJQYIKwYBBQUHAgEWGWh0dHBzOi8vd3d3LmNlcnR1bS5w
# bC9DUFMwDQYJKoZIhvcNAQEMBQADggIBAHjd7rE6Q+b32Ws4vTJeC0HcGDi7mfQU
# nbaJ9nFFOQpizPX+YIpHuK89TPkOdDF7lOEmTZzVQpw0kwpIZDuB8lSM0Gw9KloO
# vXIsGjF/KgTNxYM5aViQNMtoIiF6W9ysmubDHF7lExSToPd1r+N0zYGXlE1uEX4o
# 988K/Z7kwgE/GC649S1OEZ5IGSGmirtcruLX/xhjIDA5S/cVfz0We/ElHamHs+Uf
# W3/IxTigvvq4JCbdZHg9DsjkW+UgGGAVtkxB7qinmWJamvdwpgujAwOT1ym/giPT
# W5C8/MnkL18ZgVQ38sqKqFdqUS+ZIVeXKfV58HaWtV2Lip1Y0luL7Mswb856jz7z
# XINk79H4XfbWOryf7AtWBjrus28jmHWK3gXNhj2StVcOI48Dc6CFfXDMo/c/E/ab
# 217kTYhiht2rCWeGS5THQ3bZVx+lUPLaDe3kVXjYvxMYQKWu04QX6+vURFSeL3WV
# rUSO6nEnZu7X2EYci5MUmmUdEEiAVZO/03yLlNWUNGX72/949vU+5ZN9r9EGdp7X
# 3W7mLL1Tx4gLmHnrB97O+e9RYK6370MC52siufu11p3n8OG5s2zJw2J6LpD+HLby
# CgfRId9Q5UKgsj0A1QuoBut8FI6YdaH3sR1ponEv6GsNYrTyBtSR77csUWLUCyVb
# osF3+ae0+SofMIIGuTCCBKGgAwIBAgIRAJmjgAomVTtlq9xuhKaz6jkwDQYJKoZI
# hvcNAQEMBQAwgYAxCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hu
# b2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRo
# b3JpdHkxJDAiBgNVBAMTG0NlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0y
# MTA1MTkwNTMyMThaFw0zNjA1MTgwNTMyMThaMFYxCzAJBgNVBAYTAlBMMSEwHwYD
# VQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBD
# b2RlIFNpZ25pbmcgMjAyMSBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAJ0jzwQwIzvBRiznM3M+Y116dbq+XE26vest+L7k5n5TeJkgH4Cyk74IL9uP
# 61olRsxsU/WBAElTMNQI/HsE0uCJ3VPLO1UufnY0qDHG7yCnJOvoSNbIbMpT+Cci
# 75scCx7UsKK1fcJo4TXetu4du2vEXa09Tx/bndCBfp47zJNsamzUyD7J1rcNxOw5
# g6FJg0ImIv7nCeNn3B6gZG28WAwe0mDqLrvU49chyKIc7gvCjan3GH+2eP4mYJAS
# flBTQ3HOs6JGdriSMVoD1lzBJobtYDF4L/GhlLEXWgrVQ9m0pW37KuwYqpY42grp
# /kSYE4BUQrbLgBMNKRvfhQPskDfZ/5GbTCyvlqPN+0OEDmYGKlVkOMenDO/xtMrM
# INRJS5SY+jWCi8PRHAVxO0xdx8m2bWL4/ZQ1dp0/JhUpHEpABMc3eKax8GI1F03m
# SJVV6o/nmmKqDE6TK34eTAgDiBuZJzeEPyR7rq30yOVw2DvetlmWssewAhX+cnSa
# aBKMEj9O2GgYkPJ16Q5Da1APYO6n/6wpCm1qUOW6Ln1J6tVImDyAB5Xs3+Jriasa
# iJ7P5KpXeiVV/HIsW3ej85A6cGaOEpQA2gotiUqZSkoQUjQ9+hPxDVb/Lqz0tMjp
# 6RuLSKARsVQgETwoNQZ8jCeKwSQHDkpwFndfCceZ/OfCUqjxAgMBAAGjggFVMIIB
# UTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTddF1MANt7n6B0yrFu9zzAMsBw
# zTAfBgNVHSMEGDAWgBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMC
# AQYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDov
# L2NybC5jZXJ0dW0ucGwvY3RuY2EyLmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYB
# BQUHMAGGHGh0dHA6Ly9zdWJjYS5vY3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKG
# Jmh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQy
# MDAwLgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9D
# UFMwDQYJKoZIhvcNAQEMBQADggIBAHWIWA/lj1AomlOfEOxD/PQ7bcmahmJ9l0Q4
# SZC+j/v09CD2csX8Yl7pmJQETIMEcy0VErSZePdC/eAvSxhd7488x/Cat4ke+AUZ
# ZDtfCd8yHZgikGuS8mePCHyAiU2VSXgoQ1MrkMuqxg8S1FALDtHqnizYS1bIMOv8
# znyJjZQESp9RT+6NH024/IqTRsRwSLrYkbFq4VjNn/KV3Xd8dpmyQiirZdrONoPS
# lCRxCIi54vQcqKiFLpeBm5S0IoDtLoIe21kSw5tAnWPazS6sgN2oXvFpcVVpMcq0
# C4x/CLSNe0XckmmGsl9z4UUguAJtf+5gE8GVsEg/ge3jHGTYaZ/MyfujE8hOmKBA
# UkVa7NMxRSB1EdPFpNIpEn/pSHuSL+kWN/2xQBJaDFPr1AX0qLgkXmcEi6PFnaw5
# T17UdIInA58rTu3mefNuzUtse4AgYmxEmJDodf8NbVcU6VdjWtz0e58WFZT7tST6
# EWQmx/OoHPelE77lojq7lpsjhDCzhhp4kfsfszxf9g2hoCtltXhCX6NqsqwTT7xe
# 8LgMkH4hVy8L1h2pqGLT2aNCx7h/F95/QvsTeGGjY7dssMzq/rSshFQKLZ8lPb8h
# FTmiGDJNyHga5hZ59IGynk08mHhBFM/0MLeBzlAQq1utNjQprztZ5vv/NJy8ua9A
# GbwkMWkOMIIGuTCCBKGgAwIBAgIRAOf/acc7Nc5LkSbYdHxopYcwDQYJKoZIhvcN
# AQEMBQAwgYAxCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xv
# Z2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkxJDAiBgNVBAMTG0NlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0yMTA1
# MTkwNTMyMDdaFw0zNjA1MTgwNTMyMDdaMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQK
# ExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1l
# c3RhbXBpbmcgMjAyMSBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AOkSHwQ17bldesWmlUG+imV/TnfRbSV102aO2/hhKH9/t4NAoVoipzu0ePujH67y
# 8iwlmWuhqRR4xLeLdPxolEL55CzgUXQaq+Qzr5Zk7ySbNl/GZloFiYwuzwWS2AVg
# LPLCZd5DV8QTF+V57Y6lsdWTrrl5dEeMfsxhkjM2eOXabwfLy6UH2ZHzAv9bS/Sm
# Mo1PobSx+vHWST7c4aiwVRvvJY2dWRYpTipLEu/XqQnqhUngFJtnjExqTokt4Hyz
# Osr2/AYOm8YOcoJQxgvc26+LAfXHiBkbQkBdTfHak4DP3UlYolICZHL+XSzSXlsR
# gqiWD4MypWGU4A13xiHmaRBZowS8FET+QAbMiqBaHDM3Y6wohW07yZ/mw9ZKu/Km
# VIAEBhrXesxifPB+DTyeWNkeCGq4IlgJr/Ecr1px6/1QPtj66yvXl3uauzPPGEXU
# k6vUym6nZyE1IGXI45uGVI7XqvCt99WuD9LNop9Kd1LmzBGGvxucOo0lj1M3IRi8
# FimAX3krunSDguC5HgD75nWcUgdZVjm/R81VmaDPEP25Wj+C1reicY5CPckLGBjH
# QqsJe7jJz1CJXBMUtZs10cVKMEK3n/xD2ku5GFWhx0K6eFwe50xLUIZD9GfT7s/5
# /MyBZ1Ep8Q6H+GMuudDwF0mJitk3G8g6EzZprfMQMc3DAgMBAAGjggFVMIIBUTAP
# BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBS+VAIvv0Bsc0POrAklTp5DRBru4DAf
# BgNVHSMEGDAWgBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYw
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL2Ny
# bC5jZXJ0dW0ucGwvY3RuY2EyLmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYBBQUH
# MAGGHGh0dHA6Ly9zdWJjYS5vY3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKGJmh0
# dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQyMDAw
# LgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMw
# DQYJKoZIhvcNAQEMBQADggIBALiTWXfJTBX9lAcIoKd6oCzwQZOfARQkt0OmiQ39
# 0yEqMrStHmpfycggfPGlBHdMDDYhHDVTGyvY+WIbdsIWpJ1BNRt9pOrpXe8HMR5s
# Ou71AWOqUqfEIXaHWOEs0UWmVs8mJb4lKclOHV8oSoR0p3GCX2tVO+XF8Qnt7E6f
# bkwZt3/AY/C5KYzFElU7TCeqBLuSagmM0X3Op56EVIMM/xlWRaDgRna0hLQze5mY
# HJGv7UuTCOO3wC1bzeZWdlPJOw5v4U1/AljsNLgWZaGRFuBwdF62t6hOKs86v+jP
# IMqFPwxNJN/ou22DqzpP+7TyYNbDocrThlEN9D2xvvtBXyYqA7jhYY/fW9edUqhZ
# UmkUGM++Mvz9lyT/nBdfaKqM5otK0U5H8hCSL4SGfjOVyBWbbZlUIE8X6XycDBRR
# KEK0q5JTsaZksoKabFAyRKJYgtObwS1UPoDGcmGirwSeGMQTJSh+WR5EXZaEWJVA
# 6ZZPBlGvjgjFYaQ0kLq1OitbmuXZmX7Z70ks9h/elK0A8wOg8oiNVd3o1bb59ms1
# QF4OjZ45rkWfsGuz8ctB9/leCuKzkx5Rt1WAOsXy7E7pws+9k+jrePrZKw2DnmlN
# aT19QgX2I+hFtvhC6uOhj/CgjVEA4q1i1OJzpoAmre7zdEg+kZcFIkrDHgokA5mc
# IMK1MYIGojCCBp4CAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNv
# IERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gQ29kZSBTaWduaW5n
# IDIwMjEgQ0ECEAgyT5232pFvY+TyozxeXVEwDQYJYIZIAWUDBAIBBQCggYQwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# 78mxMOb35VyotaDRy76aKi4dyMZLQsMMY/Nji32SGe4wDQYJKoZIhvcNAQEBBQAE
# ggGAqOF+rqk9rv8YcTRBu50H9PS+cH1t9EVcVkjA5puaw05ANpQp+eUD7jOx5yM4
# 51tAEA47NmewJCmzy9/h5LiPNK5gOimrjoUyKlBbVHgKJQ8geykWhx8FCKW4aJo0
# Z/iea/HBnRoPzIJ4A3JwJqvB19BoC6JCK57OI1JIb8aNFJnZYv3C042CRjDO/ZLt
# SJM9AaT9LPG9NBIhvaHkj1fueFCD6ipx4uMHp5JYuxOQCZvIMBzliOLpSsUMi8cL
# mXmHwll2L994JusczCP7rp33Rp8XNoVZdVMsRqKqCN/JGQdQxcMpEMht5nbTJ5Tp
# c5wu2tZlrmIxR+jWNrW0YaTappZIfZe2kyuIGlAaATNaBgaQOvVef5ikQ/8xDl+1
# cVC+Ub0JNLzgcmUP8NfqRc514rCfrbr5mQtb+/JUoCdFfUnsnoAEz4ItDDPEv1A1
# w6DEFnbyUOht88KLOKX8bj/x5X+xMT5JYWc867E2yFw2WhpsAZD+I6Qa8SDoatzf
# PQJ5oYIEAjCCA/4GCSqGSIb3DQEJBjGCA+8wggPrAgEBMGowVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CWCGSAFlAwQCAgUAoIIBVjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJ
# KoZIhvcNAQkFMQ8XDTI0MDgwOTA3NDMyMVowNwYLKoZIhvcNAQkQAi8xKDAmMCQw
# IgQg6pVLsdBAtDFASNhln49hXYh0LMzgZ5LgVgJNSwA60xwwPwYJKoZIhvcNAQkE
# MTIEMO2iyDPE9zPoC+V/6FBz/UN5HoH9/Tnit8+CcRgAfsnorwfgWuR3wTS8eLIW
# dUxZDDCBnwYLKoZIhvcNAQkQAgwxgY8wgYwwgYkwgYYEFA9PuFUe/9j23n9nJrQ8
# E9Bqped3MG4wWqRYMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0
# YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAy
# MSBDQQIQCcXM+LtmfXE3qsFZgAbLMTANBgkqhkiG9w0BAQEFAASCAgCR9w/gIMuY
# UDn+fUnRSDgN2W/5JgN2Er1SJhNZB/Ov2qKrhVAMWgbjoALa4RBlsuBr7apS6uac
# TJr/SqAWnvDp/Poc7FCQKJILhgpTrhR1dmeMdbhKFDkBaeQesLDzOzG5SEm1BCxB
# 1zeehI5CLL9S7NDu040DIuDLljMabA26Y5IJEKeC8/6Q12e/sJSP8oUWN6ROZP9r
# fZBcyzYJzWeoVaSkFP/01pu2DVVNfoV5PjjxXhsqpAw0lmpZIk1JVLPWa6BSr0Rw
# DfZtBJ3+Q4oaLav6rAvxlbcDwKx+WKR51e1xsqmLJ5ZAKK9R5xzH43hF2l6a9NUx
# /Dgctx4TK6o6L7zZSRJS37rgS9hmnG2YA6kPlFyb6yOkrkQhghIxAEFXuiV8Cour
# QoB1TiqyPYCrIeS9ZdtaUvQ4NuFA9p6F73Ii8GZvR+L5ujHLaqrmvtZNB/BVNGWp
# BG93Q+xb8tTCsbiVcTj9np8gve3+iFx7y15Qsf8iNkLGW4BIyXuHZDgxyPv9TJ0i
# Ltz7rFmQmEqcVAsCYCjj9DGGz3ybOZOUr2MECTd6y3iG6Ok0RjuscvFBGSuV53zw
# uc9BmbCBsguqofTJeQKjs5G+5/g+nEluUmxuw94JPYT2XbwXLhQTlDmEdz7+yayr
# 665S677caqspo3cCS8TcW6xxn67GhHhZww==
# SIG # End signature block
