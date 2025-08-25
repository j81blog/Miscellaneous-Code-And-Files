#Requires -Version 5.1

# Define paths to public and private functions in a more robust way
$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$PrivatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

$PublicFunctions = @( Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse -ErrorAction Ignore )
$PrivateFunctions = @( Get-ChildItem -Path $PrivatePath -Filter '*.ps1' -Recurse -ErrorAction Ignore )

# Dot source all functions (both public and private) to make them available inside the module
foreach ($FunctionFile in @($PublicFunctions + $PrivateFunctions)) {
    try {
        # Unblock files downloaded from the internet
        $FunctionFile | Unblock-File -ErrorAction SilentlyContinue
        . $FunctionFile.FullName
    } catch {
        Write-Error -Message "Failed to import function '$($FunctionFile.FullName)': $_"
    }
}

# Explicitly export ONLY the public functions to the user.
# The private functions remain available inside the module, but are hidden from the user.
$ExportableFunctions = $PublicFunctions.BaseName
Export-ModuleMember -Function $ExportableFunctions

# Initialize module-wide variables
$script:WemApiConnection = $null

# Define cleanup actions for when the module is removed
$OnRemove = {
    if ($script:WemApiConnection) {
        # Attempt to gracefully disconnect any active session
        Disconnect-WEMApi
    }
}
Set-Variable -Name OnRemove -Value $OnRemove -Scope Script -Option AllScope

#Hide Progress bar
$Script:ProgressPreference = "SilentlyContinue"

if ($Global:WEMModuleHideInfo -ne $true) {
    $InformationPreference = "Continue"
    Write-Information -MessageData "`r`nConnect to your wem environment using the one of the following options:"
    Write-Information -MessageData "1. OnPrem: "
    Write-Information -MessageData "   PS C:\> Connect-WEMApi -WEMServer `"<WEM Server FQDN>`" -Credential <Your WEM Credential>`n"
    Write-Information -MessageData "2. Citrix Cloud (Web Credentials): "
    Write-Information -MessageData "   PS C:\> Connect-WEMApi -CustomerId <CustomerID> -UseSdkAuthentication`n"
    Write-Information -MessageData "3. Citrix Cloud (API Credentials): "
    Write-Information -MessageData "   PS C:\> Connect-WEMApi -CustomerId <CustomerID> -ClientId <ClientID> -ClientSecret <Secret>`n`n"
    Write-Information -MessageData "NOTE: If you want to suppress this message in the future set: "
    Write-Information -MessageData "      PS C:\> `$Global:WEMModuleHideInfo = `$true"
    $InformationPreference = "SilentlyContinue"
}
