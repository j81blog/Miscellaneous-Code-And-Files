<#
.SYNOPSIS
    Creates a detailed HTML report of folder permissions, with an optional audit mode that details why a folder deviates.

.DESCRIPTION
    This function has two modes, determined by the parameter set used:
    1. Report Mode (Default): Scans subdirectories and generates a comprehensive HTML report of all permissions.
    2. Audit Mode: Compares directory permissions against a specified JSON template. The generated report then shows only the
       deviating folders and includes a new column detailing the specific reasons for deviation (missing or unexpected permissions).

.PARAMETER Path
    The full path to the parent directory containing the folders to be scanned (e.g., "D:\HomeFolders").

.PARAMETER FilePath
    The full path where the generated HTML report file will be saved (e.g., "C:\Reports\Permissions.html").

.PARAMETER TemplatePath
    (Audit Mode) The full path to a JSON file containing the expected permissions template.

.EXAMPLE
    # Example 1: Generate a full report of all subfolders.
    New-FolderPermissionHtmlReport -Path "D:\HomeFolders" -FilePath "C:\Temp\FullReport.html"

.EXAMPLE
    # Example 2: Generate an audit report using a template with the dynamic %%FolderName%% token.
    New-FolderPermissionHtmlReport -Path "D:\HomeFolders" -FilePath "C:\Temp\AuditReport.html" -TemplatePath "C:\Templates\homefolder_template.json"

.EXAMPLE
    # Example 3: Content for the 'permissions_template.json' file used in Audit Mode.
    # Save the content below to a .json file and provide the path to the -TemplatePath parameter.

    {
        "Description": "Standard permissions for user home folders with dynamic user token.",
        "RequiredPermissions": [
            {
                "Principal": "NT AUTHORITY\\SYSTEM",
                "Rights": "FullControl",
                "Type": "Allow",
                "AppliesTo": "This folder, subfolders and files"
            },
            {
                "Principal": "BUILTIN\\Administrators",
                "Rights": "FullControl",
                "Type": "Allow",
                "AppliesTo": "This folder, subfolders and files"
            },
            {
                "Principal": "YOURDOMAIN\\%%FolderName%%",
                "Rights": "Modify",
                "Type": "Allow",
                "AppliesTo": "This folder, subfolders and files"
            }
        ]
    }

.NOTES
    Version : 4.2
    Author  : John Billekens Consultancy
    CoAuthor: Gemini (Refactored/Documentation)
    Date    : 2025-08-11
#>
function New-FolderPermissionHtmlReport {
    [CmdletBinding(DefaultParameterSetName = 'ReportSet')]
    param (
        [Parameter(ParameterSetName = 'ReportSet', Mandatory = $true, Position = 0)]
        [Parameter(ParameterSetName = 'AuditSet', Mandatory = $true, Position = 0)]
        [ValidateScript({ if (-not (Test-Path $_ -PathType Container)) { throw "Path not found or is not a directory: $_" } return $true })]
        [string]$Path,
        [Parameter(ParameterSetName = 'ReportSet', Mandatory = $true, Position = 1)]
        [Parameter(ParameterSetName = 'AuditSet', Mandatory = $true, Position = 1)]
        [ValidatePattern('\.html?$')]
        [string]$FilePath,
        [Parameter(ParameterSetName = 'AuditSet', Mandatory = $true)]
        [ValidateScript({ if (-not (Test-Path $_ -PathType Leaf)) { throw "Template file not found: $_" } return $true })]
        [string]$TemplatePath
    )

    begin {
        # Helper functions
        function Convert-RightToFriendlyName {
            param (
                [string]$RightEnumString
            )
            switch ($RightEnumString) {
                "FullControl" { return "Full control" }
                "Modify, Synchronize" { return "Modify" }
                "Modify" { return "Modify" }
                "ReadAndExecute, Synchronize" { return "Read & execute" }
                "ReadAndExecute" { return "Read & execute" }
                "Read, Synchronize" { return "Read" }
                "Read" { return "Read" }
                "Write, Synchronize" { return "Write" }
                "Write" { return "Write" }
                "ListDirectory" { return "List folder contents" }
                "Synchronize" { return "Synchronize" }
                "268435456" { return "Full control (Subonly)" }
                "1179817" { return "Read & execute" }
                "1179785" { return "Read" }
                "278" { return "Write" }
                "2032127" { return "Full control" }
                "1245631" { return "Modify" }
                "270467583" { return "Read & execute, Synchronize" }
                default { return $RightEnumString }
            }
        }
        function Convert-AppliesToFriendlyName {
            param (
                [string]$FlagsString
            )
            switch ($FlagsString) {
                "None" { return "This folder only" }
                "ContainerInherit" { return "This folder and subfolders" }
                "ObjectInherit" { return "This folder and files" }
                "ContainerInherit, ObjectInherit" { return "This folder, subfolders and files" }
                "InheritOnly, ContainerInherit" { return "Subfolders only" }
                "InheritOnly, ObjectInherit" { return "Files only" }
                "InheritOnly, ContainerInherit, ObjectInherit" { return "Subfolders and files only" }
                default { return $FlagsString }
            }
        }
        # NEW: Function to find the source of an inherited ACE
        function Get-InheritanceSource {
            param (
                [string]$ItemPath,
                [System.Security.AccessControl.FileSystemAccessRule]$AccessRule,
                [hashtable]$AclCache
            )
            $ParentPath = Split-Path -Path $ItemPath -Parent
            while ($ParentPath) {
                try {
                    if (-not $AclCache.ContainsKey($ParentPath)) {
                        $AclCache[$ParentPath] = Get-Acl -Path $ParentPath -ErrorAction Stop
                    }
                    $ParentAcl = $AclCache[$ParentPath]
                    $SourceAce = $ParentAcl.Access | Where-Object {
                        $_.IdentityReference -eq $AccessRule.IdentityReference -and
                        $_.AccessControlType -eq $AccessRule.AccessControlType -and
                        $_.InheritanceFlags -ne 'None'
                    }
                    if ($SourceAce) { return $ParentPath }
                } catch { return "&lt;source not accessible&gt;" }
                $ParentPath = Split-Path -Path $ParentPath -Parent
            }
            return "&lt;source unknown&gt;"
        }

        $IsAuditMode = ($PSCmdlet.ParameterSetName -eq 'AuditSet')
        $TemplatePermissions = @()

        if ($IsAuditMode) {
            try {
                $TemplateContent = Get-Content -Path $TemplatePath -Raw
                $TemplatePermissions = (ConvertFrom-Json -InputObject $TemplateContent).RequiredPermissions
            } catch { throw "Failed to read or parse the template file '$TemplatePath'. Error: $($_.Exception.Message)" }
        }

        # --- CSS and other one-time setup ---
        $CssStyle = @"
<style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; margin: 40px; }
    h1, h2 { color: #2c3e50; }
    h1 .mode { font-size: 0.6em; color: #95a5a6; vertical-align: middle; }
    table { border-collapse: collapse; width: 100%; box-shadow: 0 2px 3px rgba(0,0,0,0.1); }
    th, td { border: 1px solid #ddd; padding: 12px; text-align: left; vertical-align: top; word-break: break-word; }
    th { background-color: #3498db; color: white; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    tr:hover { background-color: #ecf0f1; }
    .report-header { margin-bottom: 30px; padding-bottom: 10px; border-bottom: 2px solid #3498db; }
    .nested-table { width: 100%; box-shadow: none; border: none; }
    .nested-table th { background-color: #95a5a6; }
    .nested-table td { font-size: 0.9em; border-style: none solid; }
    .nested-table tr:last-child td { border-bottom-style: none; }
    .deviation-list { margin: 0; padding-left: 20px; font-size: 0.9em; }
    .deviation-list li.missing { color: #c0392b; }
    .deviation-list li.unexpected { color: #27ae60; }
    /* UPDATED: Column widths adjusted for new column */
    .col-usergroup { width: 25%; }
    .col-right     { width: 15%; }
    .col-appliesto { width: 25%; }
    .col-inherited { width: 25%; }
    .col-type      { width: 10%; }
</style>
"@
        $ReportDate = Get-Date -Format "dddd, MMMM d, yyyy HH:mm"
        $BodyContentBuilder = [System.Text.StringBuilder]::new()
        $AclCache = @{} # NEW: Initialize the ACL cache for performance.
        $SubFolders = Get-ChildItem -Path $Path -Directory
    }

    process {
        foreach ($Folder in $SubFolders) {
            try {
                $Acl = Get-Acl -Path $Folder.FullName -ErrorAction Stop
                $AclCache[$Folder.FullName] = $Acl # Add current folder's ACL to cache
                $InheritanceEnabled = -not ($Acl.AreAccessRulesProtected)
                $IsDeviant = $false
                $DeviationReasonHtml = ''

                if ($IsAuditMode) {
                    # --- Audit Logic (Normalized) ---
                    $ActualAces = $Acl.Access | ForEach-Object { "$($_.IdentityReference -replace '\\', '\\')|$($_.FileSystemRights.ToString().ToLower())|$($_.AccessControlType.ToString().ToLower())|$(Convert-AppliesToFriendlyName -FlagsString $_.InheritanceFlags.ToString())" }
                    $ExpectedAces = $TemplatePermissions | ForEach-Object { "$($($_.Principal -replace '%%FolderName%%', $Folder.Name) -replace '\\', '\\')|$($_.Rights.ToLower())|$($_.Type.ToLower())|$($_.AppliesTo)" }

                    $Differences = Compare-Object -ReferenceObject $ExpectedAces -DifferenceObject $ActualAces -CaseSensitive # Be explicit
                    if ($Differences) {
                        $IsDeviant = $true

                        $ReasonObjects = @()
                        foreach ($Difference in $Differences) {
                            $Parts = $Difference.InputObject -split '\|'
                            $ReasonObjects += [PSCustomObject]@{
                                Principal     = $Parts[0]
                                Right         = Convert-RightToFriendlyName -RightEnumString $Parts[1]
                                DeviationType = $Difference.SideIndicator
                            }
                        }

                        $SortedReasons = $ReasonObjects | Sort-Object -Property Principal

                        $ReasonHtmlList = $SortedReasons | ForEach-Object {
                            if ($_.DeviationType -eq '<=') {
                                "<li class='missing'><b>Missing:</b> '$($_.Principal)' with right '<b>$($_.Right)</b>'.</li>"
                            } else {
                                # '=>'
                                "<li class='unexpected'><b>Unexpected:</b> '$($_.Principal)' with right '<b>$($_.Right)</b>'.</li>"
                            }
                        }
                        $DeviationReasonHtml = "<ul class='deviation-list'>$($ReasonHtmlList -join '')</ul>"
                    }
                }

                if (-not $IsAuditMode -or $IsDeviant) {
                    # --- HTML Row Generation ---
                    $PermissionsRowsBuilder = [System.Text.StringBuilder]::new()
                    foreach ($AccessRule in $Acl.Access) {
                        $FriendlyRight = Convert-RightToFriendlyName -RightEnumString $AccessRule.FileSystemRights.ToString()
                        $AppliesTo = Convert-AppliesToFriendlyName -FlagsString $AccessRule.InheritanceFlags.ToString()

                        # NEW: Determine the value for the "Inherited From" column.
                        $InheritedFrom = if ($AccessRule.IsInherited) {
                            Get-InheritanceSource -ItemPath $Folder.FullName -AccessRule $AccessRule -AclCache $AclCache
                        } else {
                            "&lt;none (this folder)&gt;"
                        }
                        # UPDATED: Added new <td> for Inherited From
                        [void]$PermissionsRowsBuilder.AppendLine("<tr><td class='col-usergroup'>$($AccessRule.IdentityReference)</td><td class='col-right'>$($FriendlyRight)</td><td class='col-appliesto'>$($AppliesTo)</td><td class='col-inherited'>$($InheritedFrom)</td><td class='col-type'>$($AccessRule.AccessControlType)</td></tr>")
                    }
                    # UPDATED: Added new <th> for Inherited From
                    $PermissionsHtml = "<table class='nested-table'><tr><th class='col-usergroup'>User / Group</th><th class='col-right'>Right</th><th class='col-appliesto'>Applies To</th><th class='col-inherited'>Inherited From</th><th class='col-type'>Type</th></tr>$($PermissionsRowsBuilder.ToString())</table>"
                    [void]$BodyContentBuilder.AppendLine("<tr><td>$($Folder.FullName)</td><td>$($Acl.Owner)</td><td>$($Folder.LastWriteTime)</td><td>$($InheritanceEnabled)</td><td>$($DeviationReasonHtml)</td><td>$($PermissionsHtml)</td></tr>")
                }
            } catch {
                [void]$BodyContentBuilder.AppendLine("<tr><td>$($Folder.FullName)</td><td colspan='5' style='color: red;'>Error processing folder: $($_.Exception.Message)</td></tr>")
            }
        }
    }

    end {
        # --- Final HTML Assembly ---
        $ReportTitle = "Folder Permissions Report"
        if ($IsAuditMode) {
            $ReportTitle += " <span class='mode'>(Audit Mode - Deviations Only)</span>"
        }
        $HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Folder Permissions Report</title>$($CssStyle)</head>
<body>
<div class='report-header'><h1>$($ReportTitle)</h1><p><strong>Scanned Path:</strong> $($Path)</p><p><strong>Report Generated:</strong> $($ReportDate)</p></div>
<table>
<thead><tr><th>Folder Name</th><th>Owner</th><th>Last Modified</th><th>Inheritance Enabled</th><th>Reason for Deviation</th><th>Advanced Permissions</th></tr></thead>
<tbody>$($BodyContentBuilder.ToString())</tbody>
</table>
</body>
</html>
"@
        try {
            $Directory = Split-Path -Path $FilePath -Parent
            if (-not (Test-Path -Path $Directory)) {
                New-Item -Path $Directory -ItemType Directory -Force | Out-Null
            }
            $HtmlContent | Out-File -FilePath $FilePath -Encoding UTF8 -ErrorAction Stop
            Write-Host "Successfully generated report: $FilePath" -ForegroundColor Green
        } catch { Write-Error "Failed to save report to '$FilePath'. Error: $($_.Exception.Message)" }
    }
}

# SIG # Begin signature block
# MIImdwYJKoZIhvcNAQcCoIImaDCCJmQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCgGDya2JKkVrgz
# MqlpnXIDuJht8F1sTM89CwamIXVpvqCCIAowggYUMIID/KADAgECAhB6I67aU2mW
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
# MC8GCSqGSIb3DQEJBDEiBCBGzqRbgo0JiANXM4o6j6IrYOGuaL6985on2vhgkjwY
# HzANBgkqhkiG9w0BAQEFAASCAYBOLjwiLq4WAmF9FTHIWPX7e5HIIP0cQSu9INln
# J6cNV8NJvKWBWvh/I23DCvFi2U3Qb4ELKl3DL0ZgcAMPLmBIH65Z5g73qqYJeSBP
# XWxIZ15L3fprsvQCkMr+GuR/3h27MW8R9vSVNJvweVYZFFaIibPOohKY/56JPy1q
# Qce1zAJGQOabahPDAgS+5/IL28wgx7cCx32KUjoU2N/h89tufT28czfismAHabuT
# ZqY/PujijiOOo+Upm6uQnohUiY7uiyQCySnKsSNdfIaY5L0SpalU4wRbAlUzYPAw
# CK9cBwzMqbY5+KSVw5Lzm3fm6Q4Yr0emtGN5BG1xyaeXbEd1NbdJX/0baiJ+wltv
# fmrGT8qfJcznxlk3n8b/qC1upjYIkk3OljAGXGaeM1E6TouefOexWxDQnxosxag1
# TQDArrTPF4/UXfe7g2zEcZLpCZLhfQXQ/sYe0HkKlJc2ynGALdtfolLo9r2qOx17
# pu/b0XK74miUDLpuuDnm8sn+qz6hggMjMIIDHwYJKoZIhvcNAQkGMYIDEDCCAwwC
# AQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNgIRAKQp
# O24e3denNAiHrXpOtyQwDQYJYIZIAWUDBAICBQCgeTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNTA4MTEyMDI3MzdaMD8GCSqGSIb3
# DQEJBDEyBDCM5B77c+6bDG1ehAWLGspoUa2z+mLtGU2AwwW49epFeJDArLtsk/3u
# /iL6nAm1pQowDQYJKoZIhvcNAQEBBQAEggIAuBJsyW0/txCZ7rUqxYXJM8Uhj578
# 7wL+QirWGND0a5t3XLW5Lh8+DzXLVGTObPhXNPh2kZLWMjF7zpDC7nktNq7rgQBK
# flBDZiGbZTzqjp4R5KkPXaaYdrO6X1rJ5lxtpAZIOSv5alkgJvL5Zuin5BkULL1i
# fcP/H1HzBGElIiRXcF5T7IqEqlfgKioHFzrFUDDWRYMoImyomUM9/yWyb67v9NtX
# io6qqsL/nF3vLrK2KVS9PVeXucl2ubiqJ4yqFPny0svxvR4diduKKbJdVzYGbnS3
# IfmUd2kedudf2pI9mml70lAxM028OVJ7o1Ncz/dtdH5MBNyF39FTq2OXJ0gfqJaD
# HbA47KBeOLLUb8WPNE0UsDsKzxPfKp/FZWn7Gw6c+xpNWCBCIHkmxc3sVD3iJZW3
# JJt3BDZYTn+Hkp839dq3zgQvGe/Tg6sOeLztCToLzVBGIEFmreZPzGCPKiUb3Ip6
# pwViAihwro28wZSCI4cTib635iBFkCrCDUU6ulMyDETdjjOJBwHhA5AYbXnBPCG/
# OnZ8II4SpMQqeOOoIC+HuBUL0HDpdjgCp8SoaGPjLTkZxfkfKLVIwPpSUNk+Qm9l
# 6n2QmY7eI9Fk+36JLoeNitqd8gdK5wn+RsG74p6amuxLsyuXexkp9a0DN+bwW3jj
# yE2cS9434khtrvI=
# SIG # End signature block
