#Requires -Version 5.1

# Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse -ErrorAction Ignore )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse -ErrorAction Ignore )

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        $import | Unblock-File
        . $import.fullname
    } catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
# setup some module wide variables
$Script:WemApiConnection = [PSCustomObject]@{
    CustomerId  = ""
    BearerToken = ""
    BaseUrl     = "https://eu-api-webconsole.wem.cloud.com"
}