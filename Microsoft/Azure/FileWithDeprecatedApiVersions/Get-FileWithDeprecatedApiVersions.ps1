function Get-FileWithDeprecatedApiVersions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [Switch]$Recurse,

        [Parameter()]
        [String[]]$FileExtensions = @("*.bicep"),

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
    $filesToScan = Get-ChildItem -Path $Path -Recurse:$Recurse -Include $($FileExtensions -join ",")
    $filesToScan | ForEach-Object {
        $fileContent = Get-Content -Path $_.FullName
        $fileName = $_.FullName
        $invalidVersions | ForEach-Object {
            if ($fileContent -match $_) {
                #return the filename and line number the invalid version was found
                Write-Output $( [PSCustomObject]@{
                        Path           = $fileName
                        LineNumber     = ($fileContent | Select-String -Pattern $_).LineNumber
                        InvalidVersion = $_
                    })
            }
        }
    }
}
