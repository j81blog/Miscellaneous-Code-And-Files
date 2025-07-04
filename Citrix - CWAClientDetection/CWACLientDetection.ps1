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
    Version        : 2025.704.1515
    Copyright      : Copyright (c) 2025 John Billekens Consultancy

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
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX307794'
    #Solved
    #Citrix Workspace App 2105 and later >=19.13.0 <21.5.0
    #Citrix Workspace App 1912 LTSR CU4 and later cumulative updates >=19.12.0 <19.12.4000

    #CVE-2023-24483
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX477616
    #Affected:
    #Citrix Workspace App versions before 2212 >=22.04.0 <22.12.0
    #Citrix Workspace App 2203 LTSR before CU2 >=19.13.0 <22.3.2000
    #Citrix Virtual Apps and Desktops 1912 LTSR before CU6  (19.12.6000.9)

    #CVE-2023-24484 & CVE-2023-24485
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX477617
    #Affected:
    #Citrix Workspace App versions before 2212 >=22.04.0 <22.12.0
    #Citrix Workspace App 2203 LTSR before CU2 >=19.13.0 <22.3.2000
    #Citrix Workspace App 1912 LTSR before CU7 Hotfix 2 <19.12.7002

    #CVE-2020-13884 & CVE-2020-13885
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX275460
    #Citrix Workspace App for Windows versions before 1912 < 19.12.0
    #Cirtrix Receiver 4.9 Cumulative Update 9 or later < 4.9.9002

    #CVE-2024-6286
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX678036
    #Affected:
    #Citrix Workspace app for Windows versions before 2203.1 LTSR CU6 Hotfix 2 <22.03.6002.6116
    #Citrix Workspace app for Windows versions before 2403.1 >=24.03.0 <24.3.1.97
    #Citrix Workspace app for Windows versions before 2402 LTSR >=22.04.0 <24.2.0.172

    #CVE-2024-7889 and CVE-2024-7890
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX691485
    #Affected:
    #Citrix Workspace app for Windows versions before 2405 >=24.03.0 <24.05.0
    #Citrix Workspace app for Windows versions before 2402 LTSR CU1 <24.2.1000.1016

    #CVE-2025-4879
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX694718
    #Affected:
    #Citrix Workspace app for Windows versions before 2409 >=24.3.0 <24.9.0
    #Citrix Workspace app for Windows versions before 2402 LTSR CU2 Hotfix 1 <24.2.2001.3
    #Citrix Workspace app for Windows versions before 2402 LTSR CU3 Hotfix 1 >=24.2.3000 <24.2.3001.9



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
        { $_ -ge [Version]"24.03.0" -and $_ -lt [Version]"24.05.0" } {
            # Citrix Workspace app for Windows versions before 2405 - CTX691485
            $isCveImpacted = $true
            $cves += "CVE-2024-7889"
            $cves += "CVE-2024-7890"
        }
        { $_ -lt [Version]"24.2.1000.1016" } {
            # Citrix Workspace app for Windows versions before 2402 LTSR CU1 - CTX691485
            $isCveImpacted = $true
            $cves += "CVE-2024-7889"
            $cves += "CVE-2024-7890"
        }
        { $_ -ge [Version]"24.3.0" -and $_ -lt [Version]"24.9.0" } {
            # Citrix Workspace app for Windows versions before 2409 - CTX694718
            $isCveImpacted = $true
            $cves += "CVE-2025-4879"
        }
        {  $_ -lt [Version]"24.2.2001.3" } {
            # Citrix Workspace app for Windows versions before 2402 LTSR CU2 Hotfix 1 - CTX694718
            $isCveImpacted = $true
            $cves += "CVE-2025-4879"
        }
        {  $_ -ge [Version]"24.2.3000" -and  $_ -lt [Version]"24.2.3001.9" } {
            # Citrix Workspace app for Windows versions before 2402 LTSR CU3 Hotfix 1 - CTX694718
            $isCveImpacted = $true
            $cves += "CVE-2025-4879"
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
        { $_ -eq [Version]"24.5.0.131" -and (Get-Date) -ge [DateTime]"2026-1-8" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"24.3.1.97" -and (Get-Date) -ge [DateTime]"2025-11-21" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"24.3.0.93" -and (Get-Date) -ge [DateTime]"2025-10-24" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.11.0.132" -and (Get-Date) -ge [DateTime]"2025-6-25" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.9.1.104" -and (Get-Date) -ge [DateTime]"2025-5-2" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.9.0.99" -and (Get-Date) -ge [DateTime]"2025-4-10" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.7.1.18" -and (Get-Date) -ge [DateTime]"2025-2-12" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.7.0.15" -and (Get-Date) -ge [DateTime]"2025-2-12" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.5.1.83" -and (Get-Date) -ge [DateTime]"2025-1-3" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.3.0.55" -and (Get-Date) -ge [DateTime]"2024-9-29" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"23.2.0.38" -and (Get-Date) -ge [DateTime]"2024-8-16" } {
            $isEOL = $true
        }
        { $_ -eq [Version]"22.12.0.48" -and (Get-Date) -ge [DateTime]"2024-7-23" } {
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
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX477618
    #Affected:
    #Citrix Workspace App versions before 2302 <23.02.0
    switch ($version) {
        { $_ -lt [Version]"23.02.0" } {
            # Citrix Workspace App versions before 2302 - CTX477618
            $isCveImpacted = $true
            $cves += "CVE-2023-24486"
        }
        { $_ -lt [Version]"22.9" -and (Get-Date) -ge [DateTime]"2024-3-29" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"22.11" -and (Get-Date) -ge [DateTime]"2024-5-08" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"22.12" -and (Get-Date) -ge [DateTime]"2024-6-1" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.2" -and (Get-Date) -ge [DateTime]"2024-8-1" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.3" -and (Get-Date) -ge [DateTime]"2024-9-23" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.5" -and (Get-Date) -ge [DateTime]"2024-11-30" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.7" -and (Get-Date) -ge [DateTime]"2025-1-6" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.9" -and (Get-Date) -ge [DateTime]"2025-4-28" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"23.11" -and (Get-Date) -ge [DateTime]"2025-7-13" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"24.2" -and (Get-Date) -ge [DateTime]"2025-9-7" } {
            $isEOL = $true
        }
        { $_ -lt [Version]"24.5" -and (Get-Date) -ge [DateTime]"2025-12-12" } {
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
    #https://support.citrix.com/support-home/kbsearch/article?articleNumber=CTX675851
    #Affected:
    #Citrix Workspace app for Mac before 2402.10 <24.02.10

    #CVE-2024-7549
    #https://support.citrix.com/s/article/CTX691484-citrix-workspace-app-for-mac-security-bulletin-for-cve20247549
    #Affected:
    #Citrix Workspace app for Mac before 2409 <24.09.0.54
    switch ($version) {
        { $_ -lt [Version]"24.02.10" } {
            # Citrix Workspace app for Mac before 2402.10 - CTX675851
            $isCveImpacted = $true
            $cves += "CVE-2024-5027"
        }
        { $_ -lt [Version]"24.09.0.54" } {
            # Citrix Workspace app for Mac before 2409 - CTX691484
            $isCveImpacted = $true
            $cves += "CVE-2024-7549"
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
        { $_ -le [Version]"24.05.0.89" -and (Get-Date) -ge [DateTime]"2026-1-9" } {
            $isEOL = $true
        }
        { $_ -le [Version]"24.02.0.78" -and (Get-Date) -ge [DateTime]"2025-10-11" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.1.0.67" -and (Get-Date) -ge [DateTime]"2025-6-21" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.09.0.4" -and (Get-Date) -ge [DateTime]"2025-3-27" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.08.0.57" -and (Get-Date) -ge [DateTime]"2025-3-15" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.07.6.64" -and (Get-Date) -ge [DateTime]"2025-1-26" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.06.0.3" -and (Get-Date) -ge [DateTime]"2024-12-22" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.05.0.36" -and (Get-Date) -ge [DateTime]"2024-11-29" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.04.0.36" -and (Get-Date) -ge [DateTime]"2024-10-13" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.01.1.60" -and (Get-Date) -ge [DateTime]"2024-9-24" } {
            $isEOL = $true
        }
        { $_ -le [Version]"23.01.0.53" -and (Get-Date) -ge [DateTime]"2024-7-12" } {
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
# MIImdwYJKoZIhvcNAQcCoIImaDCCJmQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQyacWHKi1zPin
# zI69aWPU3IwacdUonYh7Jm6advhUxKCCIAowggYUMIID/KADAgECAhB6I67aU2mW
# D5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUg
# U3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5
# WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYD
# VQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjCCAaIwDQYJ
# KoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y2ENBq26CK+z2M34mNOSJjNPvIhKA
# VD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeYXIjfa3ajoW3cS3ElcJzkyZlBnwDE
# JuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCxpectRGhhnOSwcjPMI3G0hedv2eNm
# GiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY11XxM2AVZn0GiOUC9+XE0wI7CQKf
# OUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+va8WxTlA+uBvq1KO8RSHUQLgzb1g
# bL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fWlwBp6KNL19zpHsODLIsgZ+WZ1AzC
# s1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+Gyn9/CRezKe7WNyxRf4e4bwUtrYE
# 2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kOLIaFVhf5sMM/caEZLtOYqYadtn03
# 4ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwIDAQABo4IBXDCCAVgwHwYDVR0jBBgw
# FoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYDVR0OBBYEFF9Y7UwxeqJhQo1SgLqz
# YZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/AgEAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgwBgYEVR0gADBMBgNVHR8ERTBDMEGg
# P6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3Rh
# bXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcBAQRwMG4wRwYIKwYBBQUHMAKGO2h0
# dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ1Jv
# b3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTAN
# BgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgMnoEdJVj9TC1ndK/HYiYh9lVUacah
# RoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvIyHI5UkPCbXKspioYMdbOnBWQUn73
# 3qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkkSivt51UlmJElUICZYBodzD3M/SFj
# eCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSKr+nDO+Db8qNcTbJZRAiSazr7KyUJ
# Go1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6ajTqV2ifikkVtB3RNBUgwu/mSiSU
# ice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY2752LmESsRVVoypJVt8/N3qQ1c6F
# ibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9AQO1gQrnh1TA8ldXuJzPSuALOz1Uj
# b0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNHe0pWSGH2opXZYKYG4Lbukg7HpNi/
# KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQaL0cJqlmnx9HCDxF+3BLbUufrV64
# EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWRItFA3DE8MORZeFb6BmzBtqKJ7l93
# 9bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMeYRriWklUPsetMSf2NvUQa/E5vVye
# fQIwggZFMIIELaADAgECAhAIMk+dt9qRb2Pk8qM8Xl1RMA0GCSqGSIb3DQEBCwUA
# MFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMu
# QS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQTAeFw0yNDA0
# MDQxNDA0MjRaFw0yNzA0MDQxNDA0MjNaMGsxCzAJBgNVBAYTAk5MMRIwEAYDVQQH
# DAlTY2hpam5kZWwxIzAhBgNVBAoMGkpvaG4gQmlsbGVrZW5zIENvbnN1bHRhbmN5
# MSMwIQYDVQQDDBpKb2huIEJpbGxla2VucyBDb25zdWx0YW5jeTCCAaIwDQYJKoZI
# hvcNAQEBBQADggGPADCCAYoCggGBAMslntDbSQwHZXwFhmibivbnd0Qfn6sqe/6f
# os3pKzKxEsR907RkDMet2x6RRg3eJkiIr3TFPwqBooyXXgK3zxxpyhGOcuIqyM9J
# 28DVf4kUyZHsjGO/8HFjrr3K1hABNUszP0o7H3o6J31eqV1UmCXYhQlNoW9FOmRC
# 1amlquBmh7w4EKYEytqdmdOBavAD5Xq4vLPxNP6kyA+B2YTtk/xM27TghtbwFGKn
# u9Vwnm7dFcpLxans4ONt2OxDQOMA5NwgcUv/YTpjhq9qoz6ivG55NRJGNvUXsM3w
# 2o7dR6Xh4MuEGrTSrOWGg2A5EcLH1XqQtkF5cZnAPM8W/9HUp8ggornWnFVQ9/6M
# ga+ermy5wy5XrmQpN+x3u6tit7xlHk1Hc+4XY4a4ie3BPXG2PhJhmZAn4ebNSBwN
# Hh8z7WTT9X9OFERepGSytZVeEP7hgyptSLcuhpwWeR4QdBb7dV++4p3PsAUQVHFp
# wkSbrRTv4EiJ0Lcz9P1HPGFoHiFAQQIDAQABo4IBeDCCAXQwDAYDVR0TAQH/BAIw
# ADA9BgNVHR8ENjA0MDKgMKAuhixodHRwOi8vY2NzY2EyMDIxLmNybC5jZXJ0dW0u
# cGwvY2NzY2EyMDIxLmNybDBzBggrBgEFBQcBAQRnMGUwLAYIKwYBBQUHMAGGIGh0
# dHA6Ly9jY3NjYTIwMjEub2NzcC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRw
# Oi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY2NzY2EyMDIxLmNlcjAfBgNVHSMEGDAW
# gBTddF1MANt7n6B0yrFu9zzAMsBwzTAdBgNVHQ4EFgQUO6KtBpOBgmrlANVAnyiQ
# C6W6lJwwSwYDVR0gBEQwQjAIBgZngQwBBAEwNgYLKoRoAYb2dwIFAQQwJzAlBggr
# BgEFBQcCARYZaHR0cHM6Ly93d3cuY2VydHVtLnBsL0NQUzATBgNVHSUEDDAKBggr
# BgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwDQYJKoZIhvcNAQELBQADggIBAEQsN8wg
# PMdWVkwHPPTN+jKpdns5AKVFjcn00psf2NGVVgWWNQBIQc9lEuTBWb54IK6Ga3hx
# QRZfnPNo5HGl73YLmFgdFQrFzZ1lnaMdIcyh8LTWv6+XNWfoyCM9wCp4zMIDPOs8
# LKSMQqA/wRgqiACWnOS4a6fyd5GUIAm4CuaptpFYr90l4Dn/wAdXOdY32UhgzmSu
# xpUbhD8gVJUaBNVmQaRqeU8y49MxiVrUKJXde1BCrtR9awXbqembc7Nqvmi60tYK
# lD27hlpKtj6eGPjkht0hHEsgzU0Fxw7ZJghYG2wXfpF2ziN893ak9Mi/1dmCNmor
# GOnybKYfT6ff6YTCDDNkod4egcMZdOSv+/Qv+HAeIgEvrxE9QsGlzTwbRtbm6gwY
# YcVBs/SsVUdBn/TSB35MMxRhHE5iC3aUTkDbceo/XP3uFhVL4g2JZHpFfCSu2TQr
# rzRn2sn07jfMvzeHArCOJgBW1gPqR3WrJ4hUxL06Rbg1gs9tU5HGGz9KNQMfQFQ7
# 0Wz7UIhezGcFcRfkIfSkMmQYYpsc7rfzj+z0ThfDVzzJr2dMOFsMlfj1T6l22GBq
# 9XQx0A4lcc5Fl9pRxbOuHHWFqIBD/BCEhwniOCySzqENd2N+oz8znKooSISStnkN
# aYXt6xblJF2dx9Dn89FK7d1IquNxOwt0tI5dMIIGYjCCBMqgAwIBAgIRAKQpO24e
# 3denNAiHrXpOtyQwDQYJKoZIhvcNAQEMBQAwVTELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBDQSBSMzYwHhcNMjUwMzI3MDAwMDAwWhcNMzYwMzIxMjM1OTU5
# WjByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZb3Jrc2hpcmUxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBTaWduZXIgUjM2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
# CgKCAgEA04SV9G6kU3jyPRBLeBIHPNyUgVNnYayfsGOyYEXrn3+SkDYTLs1crcw/
# ol2swE1TzB2aR/5JIjKNf75QBha2Ddj+4NEPKDxHEd4dEn7RTWMcTIfm492TW22I
# 8LfH+A7Ehz0/safc6BbsNBzjHTt7FngNfhfJoYOrkugSaT8F0IzUh6VUwoHdYDpi
# ln9dh0n0m545d5A5tJD92iFAIbKHQWGbCQNYplqpAFasHBn77OqW37P9BhOASdmj
# p3IijYiFdcA0WQIe60vzvrk0HG+iVcwVZjz+t5OcXGTcxqOAzk1frDNZ1aw8nFhG
# EvG0ktJQknnJZE3D40GofV7O8WzgaAnZmoUn4PCpvH36vD4XaAF2CjiPsJWiY/j2
# xLsJuqx3JtuI4akH0MmGzlBUylhXvdNVXcjAuIEcEQKtOBR9lU4wXQpISrbOT8ux
# +96GzBq8TdbhoFcmYaOBZKlwPP7pOp5Mzx/UMhyBA93PQhiCdPfIVOCINsUY4U23
# p4KJ3F1HqP3H6Slw3lHACnLilGETXRg5X/Fp8G8qlG5Y+M49ZEGUp2bneRLZoyHT
# yynHvFISpefhBCV0KdRZHPcuSL5OAGWnBjAlRtHvsMBrI3AAA0Tu1oGvPa/4yeei
# Ayu+9y3SLC98gDVbySnXnkujjhIh+oaatsk/oyf5R2vcxHahajMCAwEAAaOCAY4w
# ggGKMB8GA1UdIwQYMBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQWBBSI
# YYyhKjdkgShgoZsx0Iz9LALOTzAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/BAIw
# ADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEB
# AgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZn
# gQwBBAIwSgYDVR0fBEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNvbS9T
# ZWN0aWdvUHVibGljVGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEBBG4w
# bDBFBggrBgEFBQcwAoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVi
# bGljVGltZVN0YW1waW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2Nz
# cC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAYEAAoE+pIZyUSH5ZakuPVKK
# 4eWbzEsTRJOEjbIu6r7vmzXXLpJx4FyGmcqnFZoa1dzx3JrUCrdG5b//LfAxOGy9
# Ph9JtrYChJaVHrusDh9NgYwiGDOhyyJ2zRy3+kdqhwtUlLCdNjFjakTSE+hkC9F5
# ty1uxOoQ2ZkfI5WM4WXA3ZHcNHB4V42zi7Jk3ktEnkSdViVxM6rduXW0jmmiu71Z
# pBFZDh7Kdens+PQXPgMqvzodgQJEkxaION5XRCoBxAwWwiMm2thPDuZTzWp/gUFz
# i7izCmEt4pE3Kf0MOt3ccgwn4Kl2FIcQaV55nkjv1gODcHcD9+ZVjYZoyKTVWb4V
# qMQy/j8Q3aaYd/jOQ66Fhk3NWbg2tYl5jhQCuIsE55Vg4N0DUbEWvXJxtxQQaVR5
# xzhEI+BjJKzh3TQ026JxHhr2fuJ0mV68AluFr9qshgwS5SpN5FFtaSEnAwqZv3IS
# +mlG50rK7W3qXbWwi4hmpylUfygtYLEdLQukNEX1jiOKMIIGgjCCBGqgAwIBAgIQ
# NsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwFADCBiDELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYD
# VQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBS
# U0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIyMDAwMDAwWhcNMzgw
# MTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3Qg
# UjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAiJ3YuUVnnR3d6Lkm
# gZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCSJS+lV1ipnW5ihkQy
# C0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHggGsCi7uE0awqKggE
# /LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+/JUNAax3kpqstbl3
# vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi4cmisS7oSimgHUI0
# Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rWqauUP8hsokDoI7D/
# yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHdlTDEMovXAIDGAvYy
# nPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz/o2dYfdP0KWZwZIX
# bYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAsvxsAnI8Oa5s2oy25
# qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0b2iPuWLA911cRxgY
# 5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe145GWxK4O3m3gEFEI
# kv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8GA1UdIwQYMBaAFFN5
# v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0BE/8WoWyCAi/QCj0U
# JTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zATBgNVHSUEDDAKBggr
# BgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkwRzBFoEOgQYY/aHR0
# cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNlcnRpZmljYXRpb25B
# dXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEFBQcwAYYZaHR0cDov
# L29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEADr5lQe1oRLjl
# ocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX1ktLJ3+lgxtoLQhn
# 5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIiJsms9yAWnvdYOdEM
# q1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUjPfcxuFtrQdRMRi/f
# InV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOcF1VWXG8OMeM7Vy7B
# s6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7ApcmVJOtlw9FVJxw
# /mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+Pb/SIduPnmFzbSN/
# G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60mKcmaAZsEVkhOFuoj
# 4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPfS9T+JesylbHa1LtR
# V9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt5V5cQPnwtd3UOTpS
# 9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYrMBKjkb8/IN7Po0d0
# hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8wgga5MIIEoaADAgECAhEAmaOACiZVO2Wr
# 3G6EprPqOTANBgkqhkiG9w0BAQwFADCBgDELMAkGA1UEBhMCUEwxIjAgBgNVBAoT
# GVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAlBgNVBAsTHkNlcnR1bSBDZXJ0
# aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMbQ2VydHVtIFRydXN0ZWQgTmV0
# d29yayBDQSAyMB4XDTIxMDUxOTA1MzIxOFoXDTM2MDUxODA1MzIxOFowVjELMAkG
# A1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIG
# A1UEAxMbQ2VydHVtIENvZGUgU2lnbmluZyAyMDIxIENBMIICIjANBgkqhkiG9w0B
# AQEFAAOCAg8AMIICCgKCAgEAnSPPBDAjO8FGLOczcz5jXXp1ur5cTbq96y34vuTm
# flN4mSAfgLKTvggv24/rWiVGzGxT9YEASVMw1Aj8ewTS4IndU8s7VS5+djSoMcbv
# IKck6+hI1shsylP4JyLvmxwLHtSworV9wmjhNd627h27a8RdrT1PH9ud0IF+njvM
# k2xqbNTIPsnWtw3E7DmDoUmDQiYi/ucJ42fcHqBkbbxYDB7SYOouu9Tj1yHIohzu
# C8KNqfcYf7Z4/iZgkBJ+UFNDcc6zokZ2uJIxWgPWXMEmhu1gMXgv8aGUsRdaCtVD
# 2bSlbfsq7BiqljjaCun+RJgTgFRCtsuAEw0pG9+FA+yQN9n/kZtMLK+Wo837Q4QO
# ZgYqVWQ4x6cM7/G0yswg1ElLlJj6NYKLw9EcBXE7TF3HybZtYvj9lDV2nT8mFSkc
# SkAExzd4prHwYjUXTeZIlVXqj+eaYqoMTpMrfh5MCAOIG5knN4Q/JHuurfTI5XDY
# O962WZayx7ACFf5ydJpoEowSP07YaBiQ8nXpDkNrUA9g7qf/rCkKbWpQ5boufUnq
# 1UiYPIAHlezf4muJqxqIns/kqld6JVX8cixbd6PzkDpwZo4SlADaCi2JSplKShBS
# ND36E/ENVv8urPS0yOnpG4tIoBGxVCARPCg1BnyMJ4rBJAcOSnAWd18Jx5n858JS
# qPECAwEAAaOCAVUwggFRMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFN10XUwA
# 23ufoHTKsW73PMAywHDNMB8GA1UdIwQYMBaAFLahVDkCw6A/joq8+tT4HKbROg79
# MA4GA1UdDwEB/wQEAwIBBjATBgNVHSUEDDAKBggrBgEFBQcDAzAwBgNVHR8EKTAn
# MCWgI6Ahhh9odHRwOi8vY3JsLmNlcnR1bS5wbC9jdG5jYTIuY3JsMGwGCCsGAQUF
# BwEBBGAwXjAoBggrBgEFBQcwAYYcaHR0cDovL3N1YmNhLm9jc3AtY2VydHVtLmNv
# bTAyBggrBgEFBQcwAoYmaHR0cDovL3JlcG9zaXRvcnkuY2VydHVtLnBsL2N0bmNh
# Mi5jZXIwOQYDVR0gBDIwMDAuBgRVHSAAMCYwJAYIKwYBBQUHAgEWGGh0dHA6Ly93
# d3cuY2VydHVtLnBsL0NQUzANBgkqhkiG9w0BAQwFAAOCAgEAdYhYD+WPUCiaU58Q
# 7EP89DttyZqGYn2XRDhJkL6P+/T0IPZyxfxiXumYlARMgwRzLRUStJl490L94C9L
# GF3vjzzH8Jq3iR74BRlkO18J3zIdmCKQa5LyZ48IfICJTZVJeChDUyuQy6rGDxLU
# UAsO0eqeLNhLVsgw6/zOfImNlARKn1FP7o0fTbj8ipNGxHBIutiRsWrhWM2f8pXd
# d3x2mbJCKKtl2s42g9KUJHEIiLni9ByoqIUul4GblLQigO0ugh7bWRLDm0CdY9rN
# LqyA3ahe8WlxVWkxyrQLjH8ItI17RdySaYayX3PhRSC4Am1/7mATwZWwSD+B7eMc
# ZNhpn8zJ+6MTyE6YoEBSRVrs0zFFIHUR08Wk0ikSf+lIe5Iv6RY3/bFAEloMU+vU
# BfSouCReZwSLo8WdrDlPXtR0gicDnytO7eZ5827NS2x7gCBibESYkOh1/w1tVxTp
# V2Na3PR7nxYVlPu1JPoRZCbH86gc96UTvuWiOruWmyOEMLOGGniR+x+zPF/2DaGg
# K2W1eEJfo2qyrBNPvF7wuAyQfiFXLwvWHamoYtPZo0LHuH8X3n9C+xN4YaNjt2yw
# zOr+tKyEVAotnyU9vyEVOaIYMk3IeBrmFnn0gbKeTTyYeEEUz/Qwt4HOUBCrW602
# NCmvO1nm+/80nLy5r0AZvCQxaQ4xggXDMIIFvwIBATBqMFYxCzAJBgNVBAYTAlBM
# MSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0Nl
# cnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBDQQIQCDJPnbfakW9j5PKjPF5dUTANBglg
# hkgBZQMEAgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MC8GCSqGSIb3DQEJBDEiBCBN7Dahx8E/Bj3hkCH+EyUueRp61OpSQTdGGXL6pjvi
# oDANBgkqhkiG9w0BAQEFAASCAYAHqpeRuYN8YZMkaB84zzIIYXzEsAZJb9vEDWNI
# W107LJdxgCGN3UsRlmjUvhRSggiL3aegbDvXykVX6aFp2WXhjanM+2a4AUDQeYn6
# GWdbNIqRxEMDeQbiFNc1pd9Gq51TawpAWgoOBC9iDNUBEU8wQr9lXS0/ZnvGMWkJ
# 2vTvZNcx+gf+JyylFAo5+XknXqLQDyN6dF5z5PtwoRAKAmZr40Woq3xcJxlNxrYG
# vEfCZoswswYn3C+NuLuXGBAKoBiC1XJq3xPh7z6HSklixgeWRdFIhlQPgpt3GlYn
# PYmjPJVKFAAk1a3kMzS8BIEc5wSmB1ntBZ4AdPVyyMnayToZAa+zXCfuLOKSlP3A
# yGMta5f3ckoAQLHDIJ0sIG9AGu8W3ufUbo1EOzbpOf0R1rKlqtpd8TVqjzuHFAGK
# pFlnOFfF9Xyt5vowvlCXxsR77YBMqIfJAr6URt7xW4ZR1s1JUlCzn5KqM/DeaKXK
# maKDsMWnt/ELhZF/MC3GI6DbQk6hggMjMIIDHwYJKoZIhvcNAQkGMYIDEDCCAwwC
# AQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNgIRAKQp
# O24e3denNAiHrXpOtyQwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNTA3MDQxMzQ2MjBaMD8GCSqGSIb3
# DQEJBDEyBDAWa3gFPcibduYUzmXQPAjWIfiwzw3bC5c4I4DDDMl1YudcyOu/QWCX
# 8PvkqxLcB4UwDQYJKoZIhvcNAQEBBQAEggIAYcotOFtcaZKqAkaPIN1e0VHZSTG1
# cHmre8qy7soc3TR+qlsdxY8E9iPlXyXriwoPglcRb5QTD5OrKEzccB4WpEr3uWsh
# 7gaxroQ+9fQOaxTJw34ujjytw8oF7KpZZCWBoPCwM+6oE2B8bAMOrzrPDZuOl+ge
# Ar1LYUshwDSHjo1UbuHke6rGHwaJPEMbkX5izGyd4s+9YSJofizb172NRzV7Bi36
# w+IZ1pesjNOJHPJhtPkr1huLKH7XDzfInBQjZ+rU7c/oYePDZqTpiOFkYh5VnAwP
# +mubrKFBNr8Mk7Nct4Bh8cJ5dg12gQWOmzERUMxuJFBQJjBGVbcwS8SjgscNabth
# 4uWVjITJGW5GnQgwYOlPwNk4L3xlkB01Zba5TTv6uNFwT8Io5iqL9EO/Mx3bvMBH
# cvm5aIwVVerjFvqAO7qCxZgmqym9H4pTmZVS+YLLtfdpFkcFDLM9oYqmYcEG2GWH
# /cRr8bmNTzw4Ncf/uEDWSpmt/N9cQ63KPLWWMFF635oHZ/uR2RX77FvaROWvk5ic
# /hK9jA+BDxxImvx0khlmUP4BofO4EL/yxnGA8WrCUZaEVAIRUxDTpnEAiOhRZn8L
# GO2PCqdLC6QwfKMdYsoudSZm+zZhqDLA3k9WYL8YSc/DFYx6dd6H3+myv3AM0ZxK
# tmLrHfW9Xydz5R0=
# SIG # End signature block
