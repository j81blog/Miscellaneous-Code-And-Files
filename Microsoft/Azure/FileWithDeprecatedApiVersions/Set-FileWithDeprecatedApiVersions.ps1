
function Set-FileWithDeprecatedApiVersions {
    [CmdletBinding()]
    Param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]]$Path,

        [Parameter()]
        [Switch]$Recurse,

        [Parameter()]
        [String[]]$FileExtensions = @("*.bicep"),

        [Parameter()]
        [String]$NewApiVersion = "2024-04-03",

        [Parameter()]
        [string[]]$invalidVersions = @(
            "2021-08-04-preview",
            "2021-09-03-preview",
            "2022-01-12-privatepreview",
            "2022-02-10-preview",
            "2022-04-01-preview",
            "2022-08-09-privatepreview",
            "2023-01-28-privatepreview",
            "2023-01-30-preview",
            "2023-03-03-privatepreview",
            "2023-04-06-preview",
            "2023-11-01-preview",
            "2023-11-29-privatepreview",
            "2023-12-25-privatepreview",
            "2022-07-05-preview",
            "2022-09-01-privatepreview",
            "2022-10-14-preview",
            "2023-03-21-privatepreview",
            "2023-10-04-preview"
        )
    )
    Write-Verbose "Setting files with deprecated API versions to $NewApiVersion"
    Write-Verbose "We have $($Path.Count) paths to scan"
    $filesToScan = @()
    $Path | ForEach-Object {
        $filesToScan += Get-ChildItem -Path $_ -Recurse:$Recurse -Include $($FileExtensions -join ",")
    }
    Write-Verbose "Files to scan: $($filesToScan.Count)"
    $filesToScan | ForEach-Object {
        $fileContent = Get-Content -Path $_.FullName
        $fileName = $_.FullName
        $invalidVersions | ForEach-Object {
            if ($fileContent -match $_) {
                $fileContent = $fileContent -replace $_, $NewApiVersion
                Set-Content -Path $fileName -Value $fileContent
            }
        }
    }
}
