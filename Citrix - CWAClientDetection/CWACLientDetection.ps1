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

.PARAMETER EvaluateVersion
    One or more Citrix Workspace app versions to evaluate offline. Outputs one result object per
    version (Version, Platform, Release, IsLTSR, IsEOL, EndOfLife, IsCveImpacted, CVEs, Status)
    and does not show messages or log off sessions.

.PARAMETER EvaluatePlatform
    The platform used with -EvaluateVersion: Windows, Mac or Linux. Default: Windows.

.PARAMETER ReferenceDate
    The date used for the EOL check with -EvaluateVersion. Default: today.

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
    .\CWACLientDetection.ps1 -EvaluateVersion '26.3.10.69', '25.7.3000.3034' -EvaluatePlatform Windows | Format-Table -Property Version, Release, Status, CVEs
    Evaluates the specified versions offline and returns the EOL/CVE status per version.

.EXAMPLE
    .\CWACLientDetection.ps1 -JSONFilename "C:\CWACLientDetection.json" [-Test]
    Runs the script using the parameters loaded from the specified JSON file.
    You can optionally use the -Test parameter to run the script in test mode.

.NOTES
    Script    : CWACLientDetection.ps1
    Author    : John Billekens
    Copyright : Copyright (c) John Billekens Consultancy
    Version   : 2026.0927.2134
    Requires  : Windows PowerShell 5.1 or later

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
    [Switch]$Test,

    [Parameter(Mandatory = $true, ParameterSetName = 'Evaluate')]
    [ValidateNotNullOrEmpty()]
    [String[]]$EvaluateVersion,

    [Parameter(ParameterSetName = 'Evaluate')]
    [ValidateSet('Windows', 'Mac', 'Linux')]
    [String]$EvaluatePlatform = 'Windows',

    [Parameter(ParameterSetName = 'Evaluate')]
    [DateTime]$ReferenceDate = (Get-Date).Date
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

$version = '2026.0927.2134'
if ($PSCmdlet.ParameterSetName -eq "JSON") {
    if (Test-Path -Path "$JSONFilename") {
        try {
            $jsonParams = Get-Content -Path "$JSONFilename" | ConvertFrom-Json
        } catch {
            Write-Warning "Failed to load the JSON file, not formatted properly? Error: $($_.Exception.Message)"
            exit 1
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
        try {
            if ($jsonParams.RunLocal -is [bool]) {
                $RunLocal = $jsonParams.RunLocal
            } elseif ($PSBoundParameters.ContainsKey("RunLocal")) {
                $RunLocal = $RunLocal.IsPresent
            } else {
                $RunLocal = $false
            }
        } catch {
            $RunLocal = $false
        }
        Write-Verbose "RunLocal: $RunLocal"
    } else {
        Write-Warning "The JSON file does not exist"
        exit 1
    }

}
if (-not [String]::IsNullOrEmpty($MessageLogo)) {
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
function Get-CWAReleaseData {
    <#
    .SYNOPSIS
        Returns the lifecycle and CVE reference data for Citrix Workspace app per platform.

    .DESCRIPTION
        Central, data-driven source for all lifecycle (EOL) and CVE information used by the
        Test-CWA*Version functions. Update this function when Citrix publishes a new release,
        changes a lifecycle date or publishes a new security bulletin; the evaluation logic
        itself does not need to change.

        Release entries:
            Name      : Citrix release name (e.g. 2603.11).
            Min       : Lowest version (Major.Minor.Build) belonging to the release, derived
                        from the release name (YYMM.x => YY.M.x).
            Max       : (LTSR only) Exclusive upper bound of the LTSR line.
            EndOfLife : EOL date (yyyy-MM-dd) from the Citrix lifecycle page. An empty value
                        means the release is out of support without a listed date.

        CVE entries:
            Id        : CVE identifier.
            Reference : Citrix security bulletin.
            Ranges    : Affected version ranges as 'Min|Max' strings (Min inclusive, Max exclusive).

        Sources:
            https://www.citrix.com/support/product-lifecycle/workspace-app.html
            https://support.citrix.com (security bulletins as referenced per CVE)

    .EXAMPLE
        (Get-CWAReleaseData).Windows.Cves | Format-Table -Property Id, Reference

    .NOTES
        Function  : Get-CWAReleaseData
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()

    $windowsLtsr = @(
        @{ Name = '2607 LTSR'; Min = '26.7.0'; Max = '26.8.0'; EndOfLife = '2029-09-04' }
        @{ Name = '2507.1 LTSR'; Min = '25.7.0'; Max = '25.8.0'; EndOfLife = '2028-09-16' }
        @{ Name = '2402 LTSR'; Min = '24.2.0'; Max = '24.3.0'; EndOfLife = '2027-04-08' }
        @{ Name = '2203.1 LTSR'; Min = '22.3.0'; Max = '22.4.0'; EndOfLife = '2025-03-23' }
        @{ Name = '1912 LTSR'; Min = '19.12.0'; Max = '19.13.0'; EndOfLife = '' }
        @{ Name = 'Receiver 4.9 LTSR'; Min = '4.9.0'; Max = '4.10.0'; EndOfLife = '' }
    )

    $windowsCurrent = @(
        @{ Name = '2603.11'; Min = '26.3.11'; EndOfLife = '2028-02-12' }
        @{ Name = '2603.10'; Min = '26.3.10'; EndOfLife = '2027-12-18' }
        @{ Name = '2603.1'; Min = '26.3.1'; EndOfLife = '2027-11-11' }
        @{ Name = '2603'; Min = '26.3.0'; EndOfLife = '2027-10-30' }
        @{ Name = '2511.10'; Min = '25.11.10'; EndOfLife = '2027-08-17' }
        @{ Name = '2511.1'; Min = '25.11.1'; EndOfLife = '2027-07-16' }
        @{ Name = '2511'; Min = '25.11.0'; EndOfLife = '2027-06-23' }
        @{ Name = '2508.10'; Min = '25.8.10'; EndOfLife = '2027-05-03' }
        @{ Name = '2508'; Min = '25.8.0'; EndOfLife = '2027-03-29' }
        @{ Name = '2503.2'; Min = '25.3.2'; EndOfLife = '2026-11-22' }
        @{ Name = '2409.10'; Min = '24.9.10'; EndOfLife = '2026-07-16' }
        @{ Name = '2409'; Min = '24.9.0'; EndOfLife = '2026-05-26' }
        @{ Name = '2405.11'; Min = '24.5.11'; EndOfLife = '2026-04-07' }
        @{ Name = '2405.10'; Min = '24.5.10'; EndOfLife = '2026-02-08' }
        @{ Name = '2405'; Min = '24.5.0'; EndOfLife = '2026-01-08' }
        @{ Name = '2403.1'; Min = '24.3.1'; EndOfLife = '2025-11-21' }
        @{ Name = '2403'; Min = '24.3.0'; EndOfLife = '2025-10-24' }
        @{ Name = '2311'; Min = '23.11.0'; EndOfLife = '2025-06-25' }
        @{ Name = '2309.1'; Min = '23.9.1'; EndOfLife = '2025-05-02' }
        @{ Name = '2309'; Min = '23.9.0'; EndOfLife = '2025-04-10' }
        @{ Name = '2307.1'; Min = '23.7.1'; EndOfLife = '2025-02-12' }
        @{ Name = '2307'; Min = '23.7.0'; EndOfLife = '2025-02-12' }
        @{ Name = '2305.1'; Min = '23.5.1'; EndOfLife = '2025-01-03' }
        @{ Name = '2303'; Min = '23.3.0'; EndOfLife = '2024-09-29' }
        @{ Name = '2302'; Min = '23.2.0'; EndOfLife = '2024-08-16' }
        @{ Name = '2212'; Min = '22.12.0'; EndOfLife = '2024-07-23' }
        @{ Name = '2210.5'; Min = '22.10.5'; EndOfLife = '2024-06-02' }
        @{ Name = '2210'; Min = '22.10.0'; EndOfLife = '2024-05-23' }
        @{ Name = '2209'; Min = '22.9.0'; EndOfLife = '2024-04-22' }
    )

    $windowsCves = @(
        @{ Id = 'CVE-2019-11634'; Reference = 'CTX251986'; Ranges = @('0.0|4.9.6001', '4.10.0|19.4.0') }
        @{ Id = 'CVE-2020-13884'; Reference = 'CTX275460'; Ranges = @('0.0|4.9.9002', '4.10.0|19.12.0') }
        @{ Id = 'CVE-2020-13885'; Reference = 'CTX275460'; Ranges = @('0.0|4.9.9002', '4.10.0|19.12.0') }
        @{ Id = 'CVE-2020-8207'; Reference = 'CTX277662'; Ranges = @('19.12.0|19.12.1001', '20.2.0|20.8.0') }
        @{ Id = 'CVE-2021-22907'; Reference = 'CTX307794'; Ranges = @('0.0|19.12.4000', '19.13.0|21.5.0') }
        @{ Id = 'CVE-2023-24483'; Reference = 'CTX477616'; Ranges = @('0.0|19.12.6000', '19.13.0|22.3.2000', '22.4.0|22.12.0') }
        @{ Id = 'CVE-2023-24484'; Reference = 'CTX477617'; Ranges = @('0.0|19.12.7002', '19.13.0|22.3.2000', '22.4.0|22.12.0') }
        @{ Id = 'CVE-2023-24485'; Reference = 'CTX477617'; Ranges = @('0.0|19.12.7002', '19.13.0|22.3.2000', '22.4.0|22.12.0') }
        @{ Id = 'CVE-2024-6286'; Reference = 'CTX678036'; Ranges = @('0.0|22.3.6002', '22.4.0|24.2.0', '24.3.0|24.3.1') }
        @{ Id = 'CVE-2024-7889'; Reference = 'CTX691485'; Ranges = @('0.0|22.3.6003', '22.4.0|24.2.1000', '24.3.0|24.5.0') }
        @{ Id = 'CVE-2024-7890'; Reference = 'CTX691485'; Ranges = @('0.0|22.3.6003', '22.4.0|24.2.1000', '24.3.0|24.5.0') }
        @{ Id = 'CVE-2025-4879'; Reference = 'CTX694718'; Ranges = @('0.0|24.2.2001', '24.2.3000|24.2.3001', '24.3.0|24.9.0') }
        @{ Id = 'CVE-2026-78546'; Reference = 'CTX697034'; Ranges = @('0.0|25.7.3000', '25.8.0|26.3.11') }
        @{ Id = 'CVE-2026-78547'; Reference = 'CTX697034'; Ranges = @('0.0|25.7.3000', '25.8.0|26.3.11') }
    )

    $macCurrent = @(
        @{ Name = '2603.11'; Min = '26.3.11'; EndOfLife = '2027-12-24' }
        @{ Name = '2603'; Min = '26.3.0'; EndOfLife = '2027-10-06' }
        @{ Name = '2511'; Min = '25.11.0'; EndOfLife = '2027-06-19' }
        @{ Name = '2508.10'; Min = '25.8.10'; EndOfLife = '2027-04-28' }
        @{ Name = '2508'; Min = '25.8.0'; EndOfLife = '2027-03-15' }
        @{ Name = '2505.10'; Min = '25.5.10'; EndOfLife = '2027-01-30' }
        @{ Name = '2505'; Min = '25.5.0'; EndOfLife = '2027-01-02' }
        @{ Name = '2503'; Min = '25.3.0'; EndOfLife = '2026-10-09' }
        @{ Name = '2411.10'; Min = '24.11.10'; EndOfLife = '2026-08-05' }
        @{ Name = '2411'; Min = '24.11.0'; EndOfLife = '2026-06-12' }
        @{ Name = '2409.10'; Min = '24.9.10'; EndOfLife = '2026-04-24' }
        @{ Name = '2409'; Min = '24.9.0'; EndOfLife = '2026-03-16' }
        @{ Name = '2405.11'; Min = '24.5.11'; EndOfLife = '2026-02-09' }
        @{ Name = '2405'; Min = '24.5.0'; EndOfLife = '2026-01-09' }
        @{ Name = '2402.10'; Min = '24.2.10'; EndOfLife = '2025-11-23' }
        @{ Name = '2402'; Min = '24.2.0'; EndOfLife = '2025-10-11' }
        @{ Name = '2311'; Min = '23.11.0'; EndOfLife = '2025-06-21' }
        @{ Name = '2309'; Min = '23.9.0'; EndOfLife = '2025-03-27' }
        @{ Name = '2305'; Min = '23.5.0'; EndOfLife = '2024-11-29' }
        @{ Name = '2301'; Min = '23.1.0'; EndOfLife = '2024-07-12' }
    )

    $macCves = @(
        @{ Id = 'CVE-2024-5027'; Reference = 'CTX675851'; Ranges = @('0.0|24.2.10') }
        @{ Id = 'CVE-2024-7549'; Reference = 'CTX691484'; Ranges = @('0.0|24.9.0') }
        @{ Id = 'CVE-2026-18751'; Reference = 'CTX696911'; Ranges = @('0.0|26.7.0') }
    )

    $linuxCurrent = @(
        @{ Name = '2604'; Min = '26.4.0'; EndOfLife = '2027-12-23' }
        @{ Name = '2601'; Min = '26.1.0'; EndOfLife = '2027-09-05' }
        @{ Name = '2508.10'; Min = '25.8.10'; EndOfLife = '2027-06-12' }
        @{ Name = '2508'; Min = '25.8.0'; EndOfLife = '2027-04-17' }
        @{ Name = '2505'; Min = '25.5.0'; EndOfLife = '2026-12-17' }
        @{ Name = '2503'; Min = '25.3.0'; EndOfLife = '2026-09-26' }
        @{ Name = '2411'; Min = '24.11.0'; EndOfLife = '2026-06-13' }
        @{ Name = '2408'; Min = '24.8.0'; EndOfLife = '2026-04-09' }
        @{ Name = '2405'; Min = '24.5.0'; EndOfLife = '2025-12-12' }
        @{ Name = '2402'; Min = '24.2.0'; EndOfLife = '2025-09-07' }
        @{ Name = '2311'; Min = '23.11.0'; EndOfLife = '2025-07-13' }
        @{ Name = '2309'; Min = '23.9.0'; EndOfLife = '2025-03-28' }
        @{ Name = '2308'; Min = '23.8.0'; EndOfLife = '2025-02-28' }
        @{ Name = '2305'; Min = '23.5.0'; EndOfLife = '2024-11-30' }
        @{ Name = '2303'; Min = '23.3.0'; EndOfLife = '2024-09-23' }
        @{ Name = '2212'; Min = '22.12.0'; EndOfLife = '2024-06-01' }
    )

    $linuxCves = @(
        # CVE-2022-21825 only applies when App Protection is installed
        @{ Id = 'CVE-2022-21825'; Reference = 'CTX338435'; Ranges = @('20.12.0|21.12.0') }
        @{ Id = 'CVE-2023-24486'; Reference = 'CTX477618'; Ranges = @('0.0|23.2.0') }
    )

    $releaseData = @{
        Windows = @{
            Ltsr    = $windowsLtsr
            Current = $windowsCurrent
            Cves    = $windowsCves
        }
        Mac     = @{
            Ltsr    = @()
            Current = $macCurrent
            Cves    = $macCves
        }
        Linux   = @{
            Ltsr    = @()
            Current = $linuxCurrent
            Cves    = $linuxCves
        }
    }

    return $releaseData
}

function ConvertTo-CWANormalizedVersion {
    <#
    .SYNOPSIS
        Converts a version string or object to a four-part System.Version.

    .DESCRIPTION
        Parses a Citrix Workspace app version (e.g. '26.03.0.39', '26.3.10') and fills
        undefined Build/Revision parts with 0. System.Version treats an undefined part as -1,
        which makes '26.3.10' compare lower than '26.3.10.0' and breaks range checks.

    .PARAMETER Version
        The version to normalize.

    .EXAMPLE
        ConvertTo-CWANormalizedVersion -Version '26.03.10'

    .NOTES
        Function  : ConvertTo-CWANormalizedVersion
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([System.Version])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Object]$Version
    )

    process {
        $parsedVersion = $null
        if (-not [System.Version]::TryParse("$($Version)".Trim(), [ref]$parsedVersion)) {
            throw (New-Object -TypeName System.FormatException -ArgumentList "Invalid version string '$($Version)'")
        }

        $build = [System.Math]::Max($parsedVersion.Build, 0)
        $revision = [System.Math]::Max($parsedVersion.Revision, 0)
        New-Object -TypeName System.Version -ArgumentList $parsedVersion.Major, $parsedVersion.Minor, $build, $revision
    }
}

function Get-CWAVersionAssessment {
    <#
    .SYNOPSIS
        Evaluates a Citrix Workspace app version against lifecycle and CVE reference data.

    .DESCRIPTION
        Generic, platform-agnostic evaluation engine used by the Test-CWA*Version functions.

        Lifecycle resolution:
            1. LTSR: the version falls inside an LTSR line (Min <= version < Max).
            2. Current Release: the listed release in the same YY.M family with the highest
               Min <= version. When the version is below every listed release of its own family
               (unlisted build such as 2503.1), the first listed release of that family is used.
               Without a matching family, the nearest lower listed release is used.
            3. Older than the oldest listed release: EOL.
        A release is EOL when the reference date is on or after its EOL date, or when no EOL
        date is listed (legacy release).

        CVE resolution: the version is affected when it falls inside any affected range.

    .PARAMETER Version
        The client version to evaluate.

    .PARAMETER Platform
        The platform name of the reference data set (Windows, Mac or Linux).

    .PARAMETER ReferenceDate
        The date used for the EOL check. Defaults to today.

    .EXAMPLE
        Get-CWAVersionAssessment -Version '24.9.1.207' -Platform 'Windows'

    .NOTES
        Function  : Get-CWAVersionAssessment
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Windows', 'Mac', 'Linux')]
        [String]$Platform,

        [Parameter()]
        [DateTime]$ReferenceDate = (Get-Date).Date
    )

    $normalizedVersion = ConvertTo-CWANormalizedVersion -Version $Version
    $data = (Get-CWAReleaseData).$Platform
    $invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

    $matchedRelease = $null
    $isLtsrVersion = $false

    foreach ($ltsr in $data.Ltsr) {
        $ltsrMin = ConvertTo-CWANormalizedVersion -Version $ltsr.Min
        $ltsrMax = ConvertTo-CWANormalizedVersion -Version $ltsr.Max
        if ($normalizedVersion -ge $ltsrMin -and $normalizedVersion -lt $ltsrMax) {
            $matchedRelease = $ltsr
            $isLtsrVersion = $true
            break
        }
    }

    if ($null -eq $matchedRelease) {
        $releases = foreach ($release in $data.Current) {
            [PSCustomObject]@{
                Name      = $release.Name
                Min       = ConvertTo-CWANormalizedVersion -Version $release.Min
                EndOfLife = $release.EndOfLife
            }
        }

        $familyReleases = @($releases | Where-Object -FilterScript {
                $_.Min.Major -eq $normalizedVersion.Major -and $_.Min.Minor -eq $normalizedVersion.Minor
            })

        $isListedBuild = $true
        if ($familyReleases.Count -gt 0) {
            $lowerFamilyRelease = $familyReleases | Where-Object -FilterScript { $_.Min -le $normalizedVersion } |
                Sort-Object -Property Min -Descending | Select-Object -First 1
            if ($null -ne $lowerFamilyRelease) {
                $matchedRelease = $lowerFamilyRelease
            } else {
                $matchedRelease = $familyReleases | Sort-Object -Property Min | Select-Object -First 1
                $isListedBuild = $false
            }
        } else {
            $matchedRelease = $releases | Where-Object -FilterScript { $_.Min -le $normalizedVersion } |
                Sort-Object -Property Min -Descending | Select-Object -First 1
            $isListedBuild = $false
        }
    }

    $endOfLifeDate = $null
    if ($null -eq $matchedRelease) {
        $releaseName = 'Legacy (not listed)'
        $isEOL = $true
    } else {
        $releaseName = $matchedRelease.Name
        if ($isLtsrVersion -eq $false -and $isListedBuild -eq $false) {
            $releaseName = "Unlisted (lifecycle of $($matchedRelease.Name))"
        }
        if ([String]::IsNullOrEmpty($matchedRelease.EndOfLife)) {
            $isEOL = $true
        } else {
            $endOfLifeDate = [DateTime]::ParseExact($matchedRelease.EndOfLife, 'yyyy-MM-dd', $invariantCulture)
            $isEOL = ($ReferenceDate.Date -ge $endOfLifeDate)
        }
    }

    $cves = @()
    foreach ($cve in $data.Cves) {
        foreach ($range in $cve.Ranges) {
            $rangeParts = $range.Split('|')
            $rangeMin = ConvertTo-CWANormalizedVersion -Version $rangeParts[0]
            $rangeMax = ConvertTo-CWANormalizedVersion -Version $rangeParts[1]
            if ($normalizedVersion -ge $rangeMin -and $normalizedVersion -lt $rangeMax) {
                $cves += $cve.Id
                break
            }
        }
    }
    $cves = @($cves | Sort-Object -Unique)
    $isCveImpacted = ($cves.Count -gt 0)

    if ($isEOL -and $isCveImpacted) {
        $status = 'EOL & CVE'
    } elseif ($isEOL) {
        $status = 'EOL'
    } elseif ($isCveImpacted) {
        $status = 'CVE'
    } else {
        $status = 'OK'
    }

    [PSCustomObject]@{
        Version       = $normalizedVersion
        Platform      = $Platform
        Evaluated     = $true
        Release       = $releaseName
        IsLTSR        = $isLtsrVersion
        IsEOL         = $isEOL
        EndOfLife     = $endOfLifeDate
        IsCveImpacted = $isCveImpacted
        CVEs          = $cves
        Status        = $status
        UpdateInfo    = $null
    }
}

function Test-CWAWindowsVersion {
    <#
    .SYNOPSIS
        Evaluates a Citrix Workspace app for Windows version for EOL and CVE exposure.

    .DESCRIPTION
        Wrapper around Get-CWAVersionAssessment for the Windows platform. Optionally retrieves
        the latest available version from the Citrix update catalog.

    .PARAMETER Version
        The Citrix Workspace app for Windows version.

    .PARAMETER ReferenceDate
        The date used for the EOL check. Defaults to today.

    .PARAMETER SkipUpdateInfo
        Do not query the Citrix update catalog for the latest version.

    .EXAMPLE
        Test-CWAWindowsVersion -Version '25.7.3000.3034' -SkipUpdateInfo

    .NOTES
        Function  : Test-CWAWindowsVersion
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object]$Version,

        [Parameter()]
        [DateTime]$ReferenceDate = (Get-Date).Date,

        [Parameter()]
        [Switch]$SkipUpdateInfo
    )

    $assessmentParams = @{
        Version       = $Version
        Platform      = 'Windows'
        ReferenceDate = $ReferenceDate
    }
    $result = Get-CWAVersionAssessment @assessmentParams

    if (-not $SkipUpdateInfo) {
        try {
            $latestVersion = Get-LatestCWAWindowsVersionInfo
            if ($result.IsLTSR -eq $false) {
                $latestVersion = $latestVersion | Where-Object -FilterScript { $_.Stream -like 'Current' }
            }
            $result.UpdateInfo = $latestVersion
        } catch {
            Write-Warning -Message "Failed to get the latest version information, $($_.Exception.Message)"
            $result.UpdateInfo = $null
        }
    }

    Write-Output -InputObject $result
}

function Test-CWALinuxVersion {
    <#
    .SYNOPSIS
        Evaluates a Citrix Workspace app for Linux version for EOL and CVE exposure.

    .DESCRIPTION
        Wrapper around Get-CWAVersionAssessment for the Linux platform.
        Note: CVE-2022-21825 only applies when App Protection is installed.

    .PARAMETER Version
        The Citrix Workspace app for Linux version.

    .PARAMETER ReferenceDate
        The date used for the EOL check. Defaults to today.

    .EXAMPLE
        Test-CWALinuxVersion -Version '25.08.10.111'

    .NOTES
        Function  : Test-CWALinuxVersion
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object]$Version,

        [Parameter()]
        [DateTime]$ReferenceDate = (Get-Date).Date
    )

    $assessmentParams = @{
        Version       = $Version
        Platform      = 'Linux'
        ReferenceDate = $ReferenceDate
    }
    Get-CWAVersionAssessment @assessmentParams
}

function Test-CWAMacVersion {
    <#
    .SYNOPSIS
        Evaluates a Citrix Workspace app for Mac version for EOL and CVE exposure.

    .DESCRIPTION
        Wrapper around Get-CWAVersionAssessment for the Mac platform.

    .PARAMETER Version
        The Citrix Workspace app for Mac version.

    .PARAMETER ReferenceDate
        The date used for the EOL check. Defaults to today.

    .EXAMPLE
        Test-CWAMacVersion -Version '26.03.11.50'

    .NOTES
        Function  : Test-CWAMacVersion
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object]$Version,

        [Parameter()]
        [DateTime]$ReferenceDate = (Get-Date).Date
    )

    $assessmentParams = @{
        Version       = $Version
        Platform      = 'Mac'
        ReferenceDate = $ReferenceDate
    }
    Get-CWAVersionAssessment @assessmentParams
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
    foreach ($regPath in $regPaths) {
        if (Test-Path -Path $regPath) {
            # Multiple InstallDetect subkeys can exist; use the highest valid version
            $version = Get-ChildItem -Path $regPath | Get-ItemProperty | Select-Object -ExpandProperty DisplayVersion -ErrorAction SilentlyContinue |
                Where-Object -FilterScript { -not [String]::IsNullOrEmpty($_) } |
                ForEach-Object -Process { try { ConvertTo-CWANormalizedVersion -Version $_ } catch { Write-Verbose -Message "Ignoring invalid version '$($_)'" } } |
                Sort-Object -Descending | Select-Object -First 1
            if ($null -ne $version) {
                break
            }
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

    if (-not [String]::IsNullOrEmpty($Logo) -and (Test-Path -Path $Logo)) {
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

function Invoke-CWAResultAction {
    <#
    .SYNOPSIS
        Logs the evaluation result and shows the EOL/CVE message, optionally logging off the session.

    .DESCRIPTION
        Writes the evaluation result to the information stream and Application event log,
        shows the CVE message (takes precedence) or EOL message when applicable and logs off
        the session only when the matching logoff switch is set:
            - LogoffOnEOL applies only when the version is EOL.
            - LogoffOnCVE applies only when the version is CVE impacted.

    .PARAMETER Result
        The evaluation result object of a Test-CWA*Version function.

    .PARAMETER Platform
        The display name of the client platform.

    .EXAMPLE
        Invoke-CWAResultAction -Result $result -Platform 'Windows'

    .NOTES
        Function  : Invoke-CWAResultAction
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2026.0927.2134
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSCustomObject]$Result,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Platform
    )

    $hostText = @"
Citrix Workspace App version check:
Platform`t : $($Platform)
Client Version`t : $($Result.Version)
Evaluated`t : $($Result.Evaluated)
Release`t`t : $($Result.Release)
Is LTSR`t`t : $($Result.IsLTSR)
Is CVE Impacted`t : $($Result.IsCveImpacted)
Is EOL`t`t : $($Result.IsEOL)
CVE's impacted`t : $($Result.CVEs -join ', ')
"@

    Write-Information -MessageData $hostText -InformationAction Continue
    try {
        $eventLogParams = @{
            LogName     = 'Application'
            Source      = 'Application'
            EntryType   = 'Information'
            EventId     = 219
            Message     = $hostText
            ErrorAction = 'SilentlyContinue'
        }
        # 219 = 67+87+65 => C (67) W (87) A (65) => https://cryptii.com/pipes/text-decimal
        Write-EventLog @eventLogParams
    } catch {
        Write-Verbose -Message "Failed to write to the event log, $($_.Exception.Message)"
    }

    if ($Result.Evaluated -ne $true) {
        Write-Verbose -Message "Version $($Result.Version) was not evaluated for $($Platform)"
        return
    }

    $message = $null
    if ($Result.IsCveImpacted -eq $true) {
        $message = ("$($MessageTextCVE)").Replace('##platform##', $Platform)
    } elseif ($Result.IsEOL -eq $true) {
        $message = ("$($MessageTextEOL)").Replace('##platform##', $Platform)
    }

    if ($null -eq $message) {
        Write-Verbose -Message "A supported version ($($Result.Version)) was detected for $($Platform)"
        return
    }

    $logoffRequired = (($Result.IsEOL -eq $true -and [bool]$LogoffOnEOL) -or ($Result.IsCveImpacted -eq $true -and [bool]$LogoffOnCVE))
    Write-Verbose -Message "Message: $($message)"
    if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and $logoffRequired) {
        Write-Verbose -Message 'Logoff is enabled, logging off the user'
        Invoke-LogoffSession
    }
}

#end region functions

#region Evaluate

if ($PSCmdlet.ParameterSetName -eq 'Evaluate') {
    foreach ($versionToEvaluate in $EvaluateVersion) {
        try {
            switch ($EvaluatePlatform) {
                'Windows' {
                    $evaluateParams = @{
                        Version        = $versionToEvaluate
                        ReferenceDate  = $ReferenceDate
                        SkipUpdateInfo = $true
                    }
                    Test-CWAWindowsVersion @evaluateParams
                }
                'Mac' {
                    Test-CWAMacVersion -Version $versionToEvaluate -ReferenceDate $ReferenceDate
                }
                'Linux' {
                    Test-CWALinuxVersion -Version $versionToEvaluate -ReferenceDate $ReferenceDate
                }
            }
        } catch [System.FormatException] {
            Write-Warning -Message "Skipping '$($versionToEvaluate)': $($_.Exception.Message)"
        }
    }
    return
}

#end region Evaluate

$isWindowsOS = $false
try {
    if ($isWindows -eq $true) {
        $isWindowsOS = $true
    } elseif (([Environment]::OSVersion).VersionString -like '*windows*') {
        $isWindowsOS = $true
    }
} catch {
    $isWindowsOS = $false
}
Write-Verbose -Message "RunLocal      : $($RunLocal)"
Write-Verbose -Message "Test          : $($Test)"
Write-Verbose -Message "Is Windows OS : $($isWindowsOS)"

if ([bool]$RunLocal -eq $true -and [bool]$Test -eq $false -and $isWindowsOS -eq $true) {
    $clientVersion = Get-LocalWindowsCWAVersion
    $platform = 'Windows'
    if ($null -eq $clientVersion) {
        Write-Warning -Message 'Citrix Workspace app for Windows was not detected on this machine'
    } else {
        $result = Test-CWAWindowsVersion -Version $clientVersion
        Invoke-CWAResultAction -Result $result -Platform $platform
    }
} elseif ((Test-Path -Path 'HKLM:\SOFTWARE\Citrix\Ica\Session') -and ($Test -eq $false)) {
    try {
        $sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
        $connectionDetails = Get-ItemProperty -Path "HKLM:\SOFTWARE\Citrix\Ica\Session\$($sessionId)\Connection" -ErrorAction Stop
        $clientVersion = ConvertTo-CWANormalizedVersion -Version $connectionDetails.ClientVersion
        $clientPlatform = $connectionDetails.ClientProductID
    } catch {
        Write-Warning -Message "Failed to read the ICA session details, $($_.Exception.Message)"
        $clientVersion = 'Unknown'
        $clientPlatform = '0'
    }
    Write-Verbose -Message "Client PlatformID : $($clientPlatform)"
    Write-Verbose -Message "Client Version    : $($clientVersion)"
    #end region GatherMetadata

    #region basics

    $result = [PSCustomObject]@{
        Version       = $clientVersion
        Evaluated     = $false
        Release       = $null
        IsLTSR        = $false
        IsCveImpacted = $false
        IsEOL         = $false
        CVEs          = @()
    }

    #end region basics

    switch ([String]$clientPlatform) {
        '1' {
            $platform = 'Windows'
            $result = Test-CWAWindowsVersion -Version $clientVersion
        }
        '81' {
            $platform = 'Linux'
            $result = Test-CWALinuxVersion -Version $clientVersion
        }
        '82' {
            $platform = 'Mac OS'
            $result = Test-CWAMacVersion -Version $clientVersion
        }
        '83' {
            $platform = 'iOS'
        }
        '84' {
            $platform = 'Android'
        }
        '85' {
            $platform = 'Blackberry'
        }
        '86' {
            $platform = 'Windows Phone 8/WinRT'
        }
        '87' {
            $platform = 'Windows Mobile'
        }
        '88' {
            $platform = 'Blackberry Playbook'
        }
        '257' {
            $platform = 'HTML5'
        }
        default {
            $platform = 'N/A'
        }
    }

    Invoke-CWAResultAction -Result $result -Platform $platform
} elseif ([bool]$Test -eq $true) {
    Write-Verbose -Message 'Running in test mode'
    $platform = "!!TEST - v$($version) - EOL!!"
    $message = ("$($MessageTextEOL)").Replace('##platform##', $platform)
    Write-Verbose -Message "Title: $($MessageTitle)"
    Write-Verbose -Message "Message: $($message)"
    if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and [bool]$LogoffOnEOL) {
        Show-MessageToUser -Message "Your session would have been logged off now`r`n$($platform)" -Title 'Session Logoff [Test]'
    }
    $platform = "!!TEST - v$($version) - CVE!!"
    $message = ("$($MessageTextCVE)").Replace('##platform##', $platform)
    Write-Verbose -Message "Title: $($MessageTitle)"
    Write-Verbose -Message "Message: $($message)"
    if ((Show-MessageToUser -Message $message -Title $MessageTitle) -and [bool]$LogoffOnCVE) {
        Show-MessageToUser -Message "Your session would have been logged off now`r`n$($platform)" -Title 'Session Logoff [Test]'
    }
} else {
    Write-Warning -Message 'The script is not running in a Citrix environment'
}

#region Logging

if ([bool]$EnableLogging -eq $true) {
    try {
        Stop-Transcript
    } catch {
        Write-Warning -Message "Failed to stop logging, $($_.Exception.Message)"
    }
}

#end region Logging

if ($Test -eq $true) {
    Write-Host 'Press any key to continue...'
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}