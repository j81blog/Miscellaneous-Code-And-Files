<#
    .SYNOPSIS
        Removes a predefined list of Microsoft Store apps for the current user.

    .DESCRIPTION
        This function iterates through an array of AppX package names and attempts to remove
        each one for the currently logged-on user. It provides feedback on whether the
        removal was successful or if the package was not found.

        This script must be run in the context of the user for whom the apps should be removed.
        It does not require administrative privileges.

    .EXAMPLE
        PS C:\> Remove-UserStoreApps

        This command executes the function and starts the removal process for the apps
        defined in the script's internal list.

    .NOTES
        Version:      1.0
        Author:       John Billekens Consultancy
        CreationDate: 2025-08-07
        Notes:        This script only removes apps for the current user context via `Remove-AppxPackage`.
                      It does not affect other user accounts or the provisioned package for new accounts.
                      To remove provisioned packages, use `Remove-AppxProvisionedPackage` in an
                      elevated PowerShell session.
#>
function Remove-UserStoreApps {
    # Array of AppX package names to be removed.
    # Wildcards are used in the search to match partial names.
    $AppPackagesToRemove = @(
        'Microsoft.Windows.Photos',
        'Microsoft.XboxSpeechToTextOverlay',
        'MicrosoftWindows.CrossDevice',
        'Microsoft.OutlookForWindows',
        'Microsoft.MicrosoftStickyNotes',
        'Microsoft.OneDriveSync',
        'Microsoft.WindowsSoundRecorder',
        'Microsoft.Windows.DevHome',
        'Microsoft.MicrosoftOfficeHub',
        'Microsoft.Edge.GameAssist',
        'MicrosoftWindows.Client.WebExperience',
        'Microsoft.Xbox.TCUI',
        'Microsoft.GetHelp',
        'Microsoft.WindowsAlarms',
        'Microsoft.PowerAutomateDesktop',
        'Clipchamp.Clipchamp',
        'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.WindowsFeedbackHub',
        'Microsoft.XboxGamingOverlay',
        'Microsoft.YourPhone',
        'Microsoft.BingWeather',
        'Microsoft.GamingApp',
        'Microsoft.Copilot',
        'Microsoft.XboxIdentityProvider',
        'Microsoft.BingNews',
        'Microsoft.WindowsCamera',
        'Microsoft.ZuneMusic',
        'Microsoft.BingSearch'
    )

    foreach ($PackageName in $AppPackagesToRemove) {
        # Using a try/catch block to gracefully handle any errors during removal.
        try {
            # Use wildcards to find the full package name, as the provided list may contain partial names.
            # -ErrorAction SilentlyContinue prevents errors if Get-AppxPackage finds no match.
            $Package = Get-AppxPackage -Name "*$($PackageName)*" -ErrorAction SilentlyContinue

            if ($Package) {
                # Loop through results, as a wildcard can match multiple packages.
                foreach ($App in $Package) {
                    Write-Host "Attempting to remove '$($App.Name)'..."

                    Remove-AppxPackage -Package $App.PackageFullName -ErrorAction Stop

                    Write-Host "  -> Successfully removed." -ForegroundColor Green
                }
            } else {
                Write-Host "Package matching '$($PackageName)' not found for this user." -ForegroundColor Yellow
            }
        } catch {
            # If Remove-AppxPackage fails, this block will execute.
            Write-Warning "Failed to remove package matching '$($PackageName)'. Error: $($_.Exception.Message)"
        }

        # Add a blank line for better readability in the output.
        Write-Host ""
    }
}

# Call the function to start the removal process.
Remove-UserStoreApps