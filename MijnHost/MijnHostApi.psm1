#Requires -Version 5.1

# Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction Ignore )
$Private = @( Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction Ignore )

# Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
        $import | Unblock-File
        . $import.fullname
    } Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
