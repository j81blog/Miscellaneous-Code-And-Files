<#
    .SYNOPSIS
        Collects, parses, and structures new AppLocker events, creating a separate output file per user.

    .DESCRIPTION
        This advanced script queries AppLocker event logs for new events since the last run. It uses
        a timestamp file to track its state. The script collects all new events, groups them by the
        user found in the event data, and then creates a separate, uniquely named JSON file for each
        user's activity in a specified location.

    .PARAMETER All
        If specified, the script ignores the timestamp file and collects all available AppLocker events.

    .PARAMETER SaveLocation
        The mandatory directory path where the resulting JSON files will be saved.

    .EXAMPLE
        .\Get-AppLockerEvents.ps1 -SaveLocation "C:\AppLockerLogs" -Verbose
        Collects new AppLocker events and saves them to C:\AppLockerLogs, one file per user.

    .NOTES
        Version     : 1.3
        Author      : John Billekens Consultancy
        CoAuthor    : Gemini (Refactored)
        Requires    : PowerShell 5.1+ in FullLanguage mode.
#>
[CmdletBinding()]
param (
    [Parameter(HelpMessage = "Collect all events, ignoring the last run timestamp.")]
    [switch]$All,

    [Parameter(Mandatory = $true, HelpMessage = "The directory path to save the JSON output files.")]
    [ValidateScript({
            if (Test-Path -Path $_ -PathType Container) {
                return $true
            } else {
                throw "The specified SaveLocation directory does not exist: $_"
            }
        })]
    [string]$SaveLocation
)

# --- INITIALIZATION ---
# Configuration for the AppLocker event logs to query.
$AppLockerEventLogSources = @"
"EventLogs",AuditEventID,EnforceEventID
"Microsoft-Windows-AppLocker/EXE and DLL","8003","8004"
"Microsoft-Windows-AppLocker/MSI and Script","8006","8007"
"Microsoft-Windows-AppLocker/Packaged app-Deployment","8021","8022"
"Microsoft-Windows-AppLocker/Packaged app-Execution","8024","8025"
"@ | ConvertFrom-Csv

# Regex to exclude PowerShell policy test script events.
$Excludes = "^.*__PSSCRIPTPOLICYTEST_.*$"

# --- TIMESTAMP HANDLING ---
$TempPath = [System.IO.Path]::GetTempPath()
$AppLockerEventsCheckFile = Join-Path -Path $TempPath -ChildPath "AppLockerEventsCheck.txt"
$LastCheckTime = $null

if (-not $All.IsPresent -and (Test-Path -Path $AppLockerEventsCheckFile)) {
    try {
        $FileTimeData = Get-Content -Path $AppLockerEventsCheckFile -ErrorAction Stop
        $LastCheckTime = [DateTime]::FromFileTime($FileTimeData)
        Write-Verbose "Last check time read from file: $LastCheckTime"
    } catch {
        Write-Warning "Could not read or parse timestamp from '$AppLockerEventsCheckFile'. Defaulting to fetching events from the last day."
    }
}

if ($null -eq $LastCheckTime) {
    $LastCheckTime = (Get-Date).AddDays(-1)
    Write-Verbose "No valid last check time. Defaulting to getting events since: $LastCheckTime"
}

# --- EVENT COLLECTION ---
$CollectedEvents = [System.Collections.Generic.List[object]]::new()

foreach ($Source in $AppLockerEventLogSources) {
    $EventLog = $Source.EventLogs
    $AuditEventID = $Source.AuditEventID
    $EnforceEventID = $Source.EnforceEventID

    $XPathQuery = "*[System[(EventID=$AuditEventID or EventID=$EnforceEventID) and TimeCreated[@SystemTime > '$($LastCheckTime.ToUniversalTime().ToString('o'))']]]"

    $FoundEvents = Get-WinEvent -LogName $EventLog -FilterXPath $XPathQuery -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -notmatch $Excludes } | ForEach-Object {
            $EventData = $_
            $XmlData = [xml]$EventData.ToXml()
            $RuleAndFileDataXml = $XmlData.Event.UserData.RuleAndFileData

            $EventUserName = try {
                $EventData.UserId.Translate([System.Security.Principal.NTAccount]).Value
            } catch {
                $EventData.UserId.Value
            }

            $OutputObject = [ordered]@{
                TimeCreated  = $EventData.TimeCreated
                Id           = $EventData.Id
                Message      = $EventData.Message
                ComputerName = $EventData.MachineName
                UserName     = $EventUserName
                UserSID      = $EventData.UserId.Value
                XmlData      = $XmlData.OuterXml
                PolicyName   = $null
                FullFilePath = $null
                FileHash     = $null
                Fqbn         = $null
                Vendor       = $null
                ModuleName   = $null
                BinaryName   = $null
                FileVersion  = $null
            }

            if ($null -ne $RuleAndFileDataXml) {
                $OutputObject.PolicyName = $RuleAndFileDataXml.PolicyName
                $OutputObject.FullFilePath = $RuleAndFileDataXml.FullFilePath
                $OutputObject.FileHash = $RuleAndFileDataXml.FileHash
                $OutputObject.Fqbn = $RuleAndFileDataXml.Fqbn

                if (-not [string]::IsNullOrEmpty($RuleAndFileDataXml.Fqbn)) {
                    $Vendor, $ModuleName, $BinaryName, $FileVersion = $RuleAndFileDataXml.Fqbn.Split("\")
                    $OutputObject.Vendor = $Vendor
                    $OutputObject.ModuleName = $ModuleName
                    $OutputObject.BinaryName = $BinaryName
                    $OutputObject.FileVersion = $FileVersion
                }
            }
            [PSCustomObject]$OutputObject
        }

    if ($null -ne $FoundEvents) {
        $CollectedEvents.AddRange($FoundEvents)
    }
}

# --- OUTPUT AND STATE SAVING ---
if ($CollectedEvents.Count -eq 0) {
    Write-Verbose "No new AppLocker events found since the last check on $LastCheckTime."
} else {
    # Group all collected events by the UserName property.
    $GroupedEvents = $CollectedEvents | Group-Object -Property UserName

    Write-Verbose "Found $($CollectedEvents.Count) new events for $($GroupedEvents.Count) unique users. Preparing to save files."

    # Loop through each group (each user).
    foreach ($Group in $GroupedEvents) {
        $EventUserNameForFile = $Group.Name -replace '\\', '_' # Sanitize username for filename.
        $UserEvents = $Group.Group | Sort-Object TimeCreated -Descending

        $NewestUserEventDate = $UserEvents[0].TimeCreated
        $OldestUserEventDate = $UserEvents[-1].TimeCreated

        # Generate a descriptive filename for this specific user.
        $OutputFileName = '{0}_AppLockerEvents_{1:yyyyMMdd_HHmmss}-{2:yyyyMMdd_HHmmss}.json' -f $EventUserNameForFile, $OldestUserEventDate, $NewestUserEventDate
        $OutputFilePath = Join-Path -Path $SaveLocation -ChildPath $OutputFileName

        # Save this user's events to their dedicated JSON file.
        try {
            $UserEvents | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputFilePath -Force -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "Saved $($UserEvents.Count) events for user '$($Group.Name)' to '$OutputFilePath'."
        } catch {
            Write-Error "Failed to save AppLocker events for user '$($Group.Name)' to '$OutputFilePath': $($_.Exception.Message)"
        }
    }

    # After processing all groups, find the overall newest event to update the timestamp.
    $OverallNewestEvent = $CollectedEvents | Sort-Object TimeCreated -Descending | Select-Object -First 1
    if ($null -ne $OverallNewestEvent) {
        try {
            $OverallNewestEvent.TimeCreated.ToFileTime() | Set-Content -Path $AppLockerEventsCheckFile -Force -ErrorAction Stop
            Write-Verbose "Successfully updated last check timestamp to $($OverallNewestEvent.TimeCreated)."
        } catch {
            Write-Warning "Failed to update timestamp file at '$AppLockerEventsCheckFile': $($_.Exception.Message)"
        }
    }
}