
function Connect-WemApi {
    <#
    .SYNOPSIS
        Authenticates to the Citrix Cloud API and establishes a session for WEM cmdlets.
    .DESCRIPTION
        This function authenticates against the Citrix Cloud API.
        It supports two methods:
        1. Using dedicated API credentials (ClientId and ClientSecret). This is the default method.
        2. Using an existing Citrix DaaS PowerShell SDK authentication by specifying -UseSdkAuthentication.

        On success, it stores the resulting bearer token and Customer ID for use by other functions in this module.
    .PARAMETER CustomerId
        The Citrix Customer ID. This is required for both authentication methods.
    .PARAMETER ClientId
        The Client ID of the Secure Client created in Citrix Cloud Identity and Access Management. Used for API credential authentication.
    .PARAMETER ClientSecret
        The Client Secret for the specified Client ID. This should be a SecureString. Used for API credential authentication.
    .PARAMETER UseSdkAuthentication
        If specified, the function will attempt to use the authentication context from the Citrix PowerShell SDK (`Get-XDAuthentication`).
        This requires the 'Citrix.PoshSdkProxy.Commands' module to be installed.
    .EXAMPLE
        PS C:\> # Method 2: Connect using an existing Citrix SDK session
        PS C:\> Connect-WemApi -CustomerId "mycustomerid" -UseSdkAuthentication

        Uses the token from `Get-XDAuthentication` to establish the session.
    .EXAMPLE
        PS C:\> # Method 1: Connect using API credentials (interactive prompt)
        PS C:\> Connect-WemApi -CustomerId "mycustomerid"

        Prompts for Client ID and Client Secret via a secure dialog box and connects.
    .NOTES
        Version:        1.2
        Author:         John Billekens Consultancy
        Co-Author:      Gemini
        Creation Date:  2025-08-05
    #>
    [CmdletBinding(DefaultParameterSetName = 'Sdk')]
    param(
        [Parameter(ParameterSetName = 'ApiCredentials', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Sdk', Mandatory = $true)]
        [string]$CustomerId,

        [Parameter(ParameterSetName = 'ApiCredentials', Mandatory = $false)]
        [string]$ClientId,

        [Parameter(ParameterSetName = 'ApiCredentials', Mandatory = $false)]
        [System.Security.SecureString]$ClientSecret,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $true)]
        [switch]$UseSdkAuthentication
    )

    # Logic for the SDK Authentication method
    if ($PSCmdlet.ParameterSetName -eq 'Sdk') {
        Write-Verbose "Attempting to connect using Citrix SDK Authentication."

        # 1. Check if the required module is available
        if (-not (Get-Module -ListAvailable -Name 'Citrix.PoshSdkProxy.Commands')) {
            throw "The 'Citrix.PoshSdkProxy.Commands' module is not installed. Please install the Citrix PowerShell SDK to use this authentication method."
        }

        try {
            # 2. Get the authentication context from the SDK
            try {
                $ApiCredentials = Get-XDCredentials -ErrorAction Stop`
                Write-Verbose "Using existing Citrix SDK session for Customer ID: $CustomerId."
            } catch {
                Write-Verbose "No existing session found for Customer ID: $CustomerId. Attempting to authenticate."
            }
            if (-not $ApiCredentials) {
                Write-Verbose "Authenticating with Citrix DaaS service for Customer ID: $CustomerId."
                Get-XDAuthentication -CustomerId $CustomerId -ErrorAction Stop
                $ApiCredentials = Get-XDCredentials -ErrorAction Stop
            }
            if (-not $ApiCredentials.BearerToken) {
                throw "Could not retrieve a valid Bearer Token from Get-XDAuthentication. Please ensure you are authenticated with the Citrix DaaS service."
            }

            # 3. Store the connection details for other functions to use
            $script:WemApiConnection.CustomerId = $CustomerId
            $script:WemApiConnection.BearerToken = $ApiCredentials.BearerToken


            Write-Verbose "Successfully connected using Citrix SDK session for Customer ID: $($script:WemApiConnection.CustomerId)"
        } catch {
            Write-Error "Failed to authenticate using Get-XDAuthentication. Please ensure you have an active session with the Citrix DaaS service."
            Write-Error $_.Exception.Message
        }
    }
    # Logic for the API Credentials method (the original logic)
    else {
        Write-Verbose "Attempting to connect using API Credentials."

        # If credentials are not provided as parameters, prompt the user interactively.
        if (-not $PSBoundParameters.ContainsKey('ClientId') -or -not $PSBoundParameters.ContainsKey('ClientSecret')) {
            Write-Verbose "Client ID or Secret not provided, prompting for credentials."
            $CredentialPopup = Get-Credential -UserName $ClientId -Message "Enter Citrix Cloud API Client ID and Secret"
            $ClientId = $CredentialPopup.UserName
            $ClientSecret = $CredentialPopup.Password
        }

        $Uri = "https://api-eu.cloud.com/cctrustoauth2/root/tokens/clients"
        $Body = @{
            clientId     = $ClientId
            clientSecret = ([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ClientSecret)))
        }

        try {
            Write-Verbose "Requesting bearer token from Citrix Cloud API..."
            $TokenResponse = Invoke-RestMethod -Uri $Uri -Method Post -Body (ConvertTo-Json -InputObject $Body) -ContentType "application/json" -ErrorAction Stop

            $script:WemApiConnection.CustomerId = $CustomerId
            $script:WemApiConnection.BearerToken = "CWSAuth bearer=$($TokenResponse.token)"

            Write-Host "Successfully connected using API Credentials for Customer ID: $($script:WemApiConnection.CustomerId)"
        } catch {
            Write-Error "Failed to authenticate with Citrix Cloud. Please check your API credentials and permissions."
            Write-Error $_.Exception.Message
        }
    }
}
