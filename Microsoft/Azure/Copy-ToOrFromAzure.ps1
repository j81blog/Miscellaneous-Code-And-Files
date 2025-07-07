<#
    .SYNOPSIS
        Copies data from a source Azure resource to a destination Azure resource using AzCopy.

    .DESCRIPTION
        This function uses AzCopy to copy data from a source Azure resource to a destination Azure resource.
        The function requires the source and destination addresses, resource groups, and subscriptions.

    .PARAMETER SourceAddress
        Specifies the source address.

    .PARAMETER SourceResourceGroup
        Specifies the source resource group.

    .PARAMETER SourceSubscription
        Specifies the source subscription.

    .PARAMETER DestinationAddress
        Specifies the destination address.

    .PARAMETER DestinationResourceGroup
        Specifies the destination resource group.

    .PARAMETER DestinationSubscription
        Specifies the destination subscription.

    .PARAMETER SASTokenValidityHours
        Specifies the validity period of the SAS token used for authentication. The default value is 2 hours.

    .PARAMETER AzCopyPath
        Specifies the path to the AzCopy executable. The default value is the global variable $Script:GVBDevOps.AzCopy.

    .PARAMETER Overwrite
        Specifies the overwrite behavior. The default value is "true". The possible values are:
        - true: Overwrites the destination file if the source file is newer.
        - false: Does not overwrite the destination file.
        - prompt: Prompts the user to overwrite the destination file.
        - ifSourceNewer: Overwrites the destination file if the source file is newer.

    .PARAMETER PreservePermissions
        Preserves the permissions of the source file.

    .PARAMETER PreserveSMBPermissions
        Preserves the SMB permissions of the source file.

    .PARAMETER PreserveSMBInfo
        Preserves the SMB information of the source file.

    .PARAMETER Recurse
        Copies all files in the source directory and all subdirectories.

    .PARAMETER AsSubdir
        Copies the source directory as a subdirectory in the destination directory.

    .PARAMETER NotAsSubdir
        Copies the source directory as a directory in the destination directory.

    .PARAMETER LogFilePath
        Specifies the path to the log file. The default value is the system temporary folder.

    .PARAMETER WhatIf
        Simulates the operation if specified.

    .EXAMPLE
        $copyParams = @{
            SourceAddress = "https://source.blob.core.windows.net/container"
            SourceResourceGroup = "sourceRG"
            SourceSubscription = "sourceSub"
            DestinationAddress = "https://destination.blob.core.windows.net/container"
            DestinationResourceGroup = "destinationRG"
            DestinationSubscription = "destinationSub"
            SASTokenValidityHours = 4
            AzCopyPath = "C:\Temp\azcopy.exe"
            WhatIf = $true
        }
        Copy-ToOrFromAzure @copyParams

        Simulates (Dry run) copying data from the source Azure resource to the destination Azure resource using AzCopy.

    .EXAMPLE
        $copyParams = @{
            SourceAddress = "https://source.blob.core.windows.net/container"
            SourceResourceGroup = "sourceRG"
            SourceSubscription = "sourceSub"
            DestinationAddress = "https://destination.blob.core.windows.net/container"
            DestinationResourceGroup = "destinationRG"
            DestinationSubscription = "destinationSub"
            SASTokenValidityHours = 4
            AzCopyPath = "C:\Temp\azcopy.exe"
            WhatIf = $true
        }
        Copy-ToOrFromAzure @copyParams

        Copying data from the source Azure resource to the destination Azure resource using AzCopy.

    .NOTES
        Function : Copy-ToOrFromAzure
        Author   : John Billekens
        Copyright: Copyright (c) John Billekens Consultancy
        Version  : 1.6

        Version History:
        1.0 - Initial version
        1.1 - Added support for Azure File Storage
        1.2 - Added support for SAS token validity period
        1.3 - Added support for AzCopy path
        1.4 - Added support for overwrite behavior
        1.5 - Added support for preserving permissions and (sub)folder copying
        1.6 - Added support for preserving SMB permissions and info

#>
Function Copy-ToOrFromAzure {
    [CmdletBinding()]
    Param (
        [ValidateNotNullOrEmpty()]
        [String]$SourceAddress,

        [String]$SourceResourceGroup,

        [String]$SourceSubscription,

        [String]$DestinationAddress,

        [String]$DestinationResourceGroup,

        [String]$DestinationSubscription,

        [Int]$SASTokenValidityHours = 2,

        [String]$LogFilePath = ${env:TEMP},

        [String]$AzCopyPath = "$($PSScriptRoot)\azcopy.exe",

        [ValidateSet("true", "false", "prompt", "ifSourceNewer")]
        [String]$Overwrite = "true",

        [Switch]$PreservePermissions,

        [Switch]$PreserveSMBPermissions,

        [Switch]$PreserveSMBInfo,

        [Switch]$AsSubdir,

        [Switch]$NotAsSubdir,

        [Switch]$Recurse,

        [Switch]$WhatIf
    )

    Import-Module Az.Storage
    Import-Module Az.Accounts

    if (-Not (Test-Path -Path $AzCopyPath)) {
        Throw "AzCopy not found at $AzCopyPath"
        Exit 1
    }
    if (-Not (Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction SilentlyContinue)) {
        Write-Host "Not logged in to Azure, logging in now"
        Connect-AzAccount | Out-Null
    }
    $outputResults = @{
        ExitCode = 1
        ErrorMsg = "Unknown error"
    }
    try {
        Write-Host "Generate expiration date/time for SAS token"
        $sasExpiration = (Get-Date).AddHours($SASTokenValidityHours)
        Write-Host "SAS Expiration: $($sasExpiration)"
        $SourceIsAzure = $false
        if ($SourceAddress -like "*blob.core.windows.net*") {
            $sourceSAService = "Blob"
            Write-Host "Source is Azure ($sourceSAService) => $SourceAddress"
            $SourceIsAzure = $true
            if ([String]::IsNullOrEmpty($SourceResourceGroup) -or [String]::IsNullOrEmpty($SourceSubscription)) {
                Throw "Source resource group and subscription are required for Azure source"
            }
        } elseif ($SourceAddress -like "*file.core.windows.net*") {
            $sourceSAService = "File"
            Write-Host "Source is Azure ($sourceSAService) => $SourceAddress"
            $SourceIsAzure = $true
            if ([String]::IsNullOrEmpty($SourceResourceGroup) -or [String]::IsNullOrEmpty($SourceSubscription)) {
                Throw "Source resource group and subscription are required for Azure source"
            }
        } else {
            Write-Host "Source is not Azure => $SourceAddress"
        }
        if ($DestinationAddress -like "*blob.core.windows.net*") {
            $destinationSAService = "Blob"
            Write-Host "Destination is Azure ($destinationSAService) => $DestinationAddress"
            $destinationIsAzure = $true
            if ([String]::IsNullOrEmpty($DestinationResourceGroup) -or [String]::IsNullOrEmpty($DestinationSubscription)) {
                Throw "Destination resource group and subscription are required for Azure destination"
            }
        } elseif ($DestinationAddress -like "*file.core.windows.net*") {
            $destinationSAService = "File"
            Write-Host "Destination is Azure ($destinationSAService) => $DestinationAddress"
            $destinationIsAzure = $true
            if ([String]::IsNullOrEmpty($DestinationResourceGroup) -or [String]::IsNullOrEmpty($DestinationSubscription)) {
                Throw "Destination resource group and subscription are required for Azure destination"
            }
        } else {
            Write-Host "Destination is not Azure => $DestinationAddress"
        }

        Write-Host "##[section]Determining source details"
        if ($SourceIsAzure) {
            Write-Host "Collecting Azure source details"
            Write-Host "Set Context to source subscription `"$SourceSubscription`""
            $actionSection = "Source Set-AzContext"
            Write-Host "##[group]Results (Source Context)"
            Write-Host "$(Set-AzContext -SubscriptionId $SourceSubscription | Select-Object Name, Account | Format-List | Out-String)"
            Write-Host "Context set to `"$SourceSubscription`""
            Write-Host "##[endgroup]"

            Write-Host "Extracting source information"
            if ($SourceAddress -like "http?://*") {
                $SourceSAFQDN, $SourceSAContainer, $SourceSAPath = $SourceAddress.TrimStart("http://").TrimStart("https://").Split("/")
            } else {
                $SourceSAFQDN, $SourceSAContainer, $SourceSAPath = $SourceAddress.TrimStart("\\").Split("\")
            }
            $SourceSAName = ($SourceSAFQDN.Split("."))[0]
            Write-Host "Got the SA Name: $($SourceSAName)"

            #region Set destination SAS Token
            Write-Host "Get-AzStorageAccountKey for [Storage account: $($SourceSAName)] in [Resource Group: $($SourceResourceGroup)]"
            $actionSection = "Source Get-AzStorageAccountKey"
            $sourceStorageAccountKey = (Get-AzStorageAccountKey -resourcegroup $SourceResourceGroup -AccountName $SourceSAName -ErrorAction Stop).value[0]
            Write-Host "Get-AzStorageAccountKey: Done"

            Write-Host "New-AzStorageContext for [Storage account: $($SourceSAName)] using AzStorageAccountKey"
            $actionSection = "Source New-AzStorageContext"
            $sourceContext = (New-AzStorageContext -StorageAccountName $SourceSAName -StorageAccountKey $sourceStorageAccountKey -ErrorAction Stop).context
            Write-Host "New-AzStorageContext: Done"

            Write-Host "Determining the service"
            $actionSection = "Source Get-AzStorageBlob / Get-AzStorageFile"
            Write-Host "Source Get-AzStorageBlob / Get-AzStorageFile for [Storage account: $($sourceContext.StorageAccountName) | Container: $($SourceSAContainer)]"

            Write-Host "New-AzStorageAccountSASToken for [Storage account: $($SourceSAName)]"
            $actionSection = "Source New-AzStorageAccountSASToken"
            $sourceSasToken = New-AzStorageAccountSASToken -Context $sourceContext -Service $sourceSAService -ResourceType Service, Container, Object -Permission "rl" -ExpiryTime $sasExpiration -Protocol HttpsOnly -WarningAction SilentlyContinue -ErrorAction Stop
            Write-Host "New-AzStorageAccountSASToken: Done"

            switch ($SourceSAService) {
                "Blob" {
                    if ($PreserveSMBPermissions -or $PreserveSMBInfo) {
                        Throw "Preserving SMB permissions and info is not supported for Blob storage"
                    }
                    $sourcePath = ([uri]('{0}{1}/{2}?{3}' -f $sourceContext.BlobEndPoint, $SourceSAContainer, $($SourceSAPath -join "/"), $sourceSasToken.TrimStart("?"))).AbsoluteUri
                    Write-Host "Blob path constructed"
                    Break
                }
                "File" {
                    $sourcePath = ([uri]('{0}{1}/{2}?{3}' -f $sourceContext.FileEndPoint, $SourceSAContainer, $($SourceSAPath -join "/"), $sourceSasToken.TrimStart("?"))).AbsoluteUri
                    Write-Host "File path constructed"
                    Break
                }
                Default {
                    Throw "Unknown (source) service detected"
                }
            }
            Write-Verbose "Source path: $sourcePath"
        } else {
            Write-Host "Using source address as is: `"$SourceAddress`""
            $sourcePath = "`"$SourceAddress`""
        }

        Write-Host "##[section]Determining destination details"
        if ($destinationIsAzure) {
            Write-Host "Collecting Azure destination details"
            Write-Host "Set Context to destination subscription `"$DestinationSubscription`""
            $actionSection = "Destination Set-AzContext"
            Write-Host "##[group]Results (Destination Context)"
            Write-Host "$(Set-AzContext -SubscriptionId $DestinationSubscription | Select-Object Name, Account | Format-List | Out-String)"
            Write-Host "Context set to `"$DestinationSubscription`""
            Write-Host "##[endgroup]"

            Write-Host "Extracting destination information"
            if ($DestinationAddress -like "http?://*") {
                $DestinationSAFQDN, $DestinationSAContainer, $DestinationSAPath = $DestinationAddress.TrimStart("http://").TrimStart("https://").Split("/")
            } else {
                $DestinationSAFQDN, $DestinationSAContainer, $DestinationSAPath = $DestinationAddress.TrimStart("\\").Split("\")
            }
            $DestinationSAName = ($DestinationSAFQDN.Split("."))[0]
            Write-Host "Got the SA Name: $($DestinationSAName)"

            #region Set destionation SAS Token
            Write-Host "Get-AzStorageAccountKey for [Storage account: $($DestinationSAName)] in [Resource Group: $($DestinationResourceGroup)]"
            $actionSection = "Destination Get-AzStorageAccountKey"
            $DestinationStorageAccountKey = (Get-AzStorageAccountKey -resourcegroup $DestinationResourceGroup -AccountName $DestinationSAName -ErrorAction Stop).value[0]
            Write-Host "Get-AzStorageAccountKey: Done"

            Write-Host "New-AzStorageContext for [Storage account: $($DestinationSAName)] using AzStorageAccountKey"
            $actionSection = "Destination New-AzStorageContext"
            $destinationContext = (New-AzStorageContext -StorageAccountName $DestinationSAName -StorageAccountKey $DestinationStorageAccountKey -ErrorAction Stop).context
            Write-Host "New-AzStorageContext: Done"

            Write-Host "Determining the service"
            $actionSection = "Destination Get-AzStorageBlob / Get-AzStorageFile"
            Write-Host "Destination Get-AzStorageBlob / Get-AzStorageFile for [Storage account: $($destinationContext.StorageAccountName) | Container: $($DestinationSAContainer)]"

            Write-Host "New-AzStorageAccountSASToken for [Storage account: $($DestinationSAName)]"
            $actionSection = "Destination New-AzStorageAccountSASToken"
            $destinationSasToken = New-AzStorageAccountSASToken -Context $destinationContext -Service $DestinationSAService -ResourceType Service, Container, Object -Permission "racwdlup" -Protocol HttpsOnly -ExpiryTime $sasExpiration -WarningAction SilentlyContinue -ErrorAction Stop
            Write-Host "New-AzStorageAccountSASToken: Done"

            switch ($DestinationSAService) {
                "Blob" {
                    if ($PreserveSMBPermissions -or $PreserveSMBInfo) {
                        Throw "Preserving SMB permissions and info is not supported for Blob storage"
                    }
                    $destinationPath = ([uri]('{0}{1}/{2}?{3}' -f $destinationContext.BlobEndPoint, $DestinationSAContainer, $($DestinationSAPath -join "/"), $destinationSasToken.TrimStart("?"))).AbsoluteUri
                    Write-Host "Blob path constructed"
                    Break
                }
                "File" {
                    $destinationPath = ([uri]('{0}{1}/{2}?{3}' -f $destinationContext.FileEndPoint, $DestinationSAContainer, $($DestinationSAPath -join "/"), $destinationSasToken.TrimStart("?"))).AbsoluteUri
                    Write-Host "File path constructed"
                    Break
                }
                Default {
                    Throw "Unknown (destination) service detected"
                }
            }
            Write-Verbose "Destination path: $destinationPath"
        } else {
            Write-Host "Using destination address as is: `"$DestinationAddress`""
            $destinationPath = "`"$DestinationAddress`""
        }
        Write-Host "[section]Start copying data"
        Write-Host "Set copy-log file location to $LogFilePath"
        $env:AZCOPY_LOG_LOCATION = $LogFilePath

        $params = @()
        $params += "copy"
        $params += $sourcePath
        $params += $destinationPath
        $params += "--recursive=$($Recurse.ToString().ToLower())"

        if ($WhatIf) {
            $params += "--dry-run"
        }
        if (-Not [String]::IsNullOrEmpty($Overwrite)) {
            $params += "--overwrite=$Overwrite"
        }
        if ($AsSubdir) {
            $params += "--as-subdir=true"
        }
        if ($NotAsSubdir) {
            $params += "--as-subdir=false"
        }
        if ($PreservePermissions) {
            $params += "--preserve-permissions"
            $params += "--backup"
        }
        if ($PreserveSMBPermissions) {
            $params += "--preserve-smb-permissions"
        }
        if ($PreserveSMBInfo) {
            $params += "--preserve-smb-info"
        }
        $params += "--output-type json"
        Write-Verbose "AzCopy parameters: $($params -join " ")"
        $actionSection = "AzCopy"
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $AzCopyPath
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.Arguments = $params
        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        Write-Host "Parameters gathered, starting AzCopy"
        $p.Start() | Out-Null

        $result = [pscustomobject]@{
            Title     = ($MyInvocation.MyCommand).Name
            Command   = $AzCopyPath
            Arguments = $params
            StdOut    = $p.StandardOutput.ReadToEnd()
            StdErr    = $p.StandardError.ReadToEnd()
            ExitCode  = $p.ExitCode
        }
        $p.WaitForExit()
        $results = $result.StdOut.split("`n") | ForEach-Object { $_ | ConvertFrom-Json }
        $endOfJob = $results | Where-Object { $_.MessageType -like "EndOfJob" } | Select-Object -ExpandProperty MessageContent | ConvertFrom-Json
        Write-Host "AzCopy completed [$($p.ExitCode)], parsing results"
        Write-Host "##[group]AzCopy results"
        Write-Host "AzCopy results: $($endOfJob | Out-String)"
        Write-Host "##[endgroup]"
        $outputResults = @{
            FinalJobStatus = $endOfJob.JobStatus
            ExitCode       = $p.ExitCode
            Results        = $endOfJob
            ErrorMsg       = $endOfJob.ErrorMsg
        }
        Write-Output $outputResults
    } catch {
        Write-Verbose "Full Error Details:`r`n$( Get-ExceptionDetails $_ )"
        Write-Error -Message "Error while executing section $actionSection, $($_.Exception.Message)" -ErrorAction Stop
    }
    if ($outputResults.ExitCode -ne 0) {
        Write-Error "AzCopy failed, exit code: $($p.ExitCode) $($outputResults.ErrorMsg)" -ErrorAction Stop
    }
}

