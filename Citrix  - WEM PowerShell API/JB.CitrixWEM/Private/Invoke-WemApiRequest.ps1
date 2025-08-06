
function Invoke-WemApiRequest {
    <#
    .SYNOPSIS
        A private helper function to handle web requests to the WEM API.
    .DESCRIPTION
        This function centralizes the logic for making authenticated API calls to the Citrix WEM service.
        It constructs the necessary headers, builds the full URI, and executes the web request.
        This function is not intended to be called directly from outside this script/module.
    .PARAMETER UriPath
        Specifies the path of the API endpoint, which will be combined with the base URL.
        For example: "services/wem/webPrinter".
    .PARAMETER Method
        Specifies the HTTP method to use for the request (e.g., GET, POST, DELETE).
    .PARAMETER BearerToken
        The authentication bearer token for the API session.
    .PARAMETER CustomerId
        The Citrix Customer ID.
    .PARAMETER Body
        An optional object that will be converted to a JSON string for the request body. Used for POST/PUT requests.
    .NOTES
        Version:        1.3
        Author:         John Billekens Consultancy
        Co-Author:      Gemini
        Creation Date:  2025-08-05
    #>
    [CmdletBinding(DefaultParameterSetName = 'Sdk')]
    param(
        [Parameter(ParameterSetName = 'Sdk', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Connection', Mandatory = $true)]
        [string]$UriPath,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Connection', Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
        [string]$Method,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BearerToken = $script:WemApiConnection.BearerToken,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[a-zA-Z0-9-]+$")]
        [string]$CustomerId = $script:WemApiConnection.CustomerId,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $false)]
        [Parameter(ParameterSetName = 'Connection', Mandatory = $false)]
        [object]$Body,

        [Parameter(ParameterSetName = 'Sdk', Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseUrl = $script:WemApiConnection.BaseUrl,

        [Parameter(ParameterSetName = 'Connection', Mandatory = $true)]
        [PSCustomObject]$Connection
    )


    # Define headers required for the API call
    $Headers = @{
        "Accept"          = "application/json,"
        "Accept-Encoding" = "gzip, deflate, br, zstd"
    }
    if ($PSCmdlet.ParameterSetName -eq 'Connection') {
        $Headers.Add("Authorization", "$($Connection.BearerToken)")
        $FullUri = "$($Connection.BaseUrl)/$($UriPath.TrimStart('/'))"

    } else {
        $Headers.Add("Authorization", "$BearerToken")
        $FullUri = "$($BaseUrl)/$($UriPath.TrimStart('/'))"
    }

    if (-not [string]::IsNullOrEmpty($CustomerId)) {
        $Headers.Add("Citrix-CustomerId", "$CustomerId")
    }
    Write-Verbose "Constructed API URI: $FullUri"
    Write-Verbose "Using HTTP Method: $Method"
    Write-Verbose "Headers: $($Headers | Out-String)"

    # Parameters for Invoke-WebRequest (Splatting)
    $ApiSplat = @{
        UseBasicParsing = $true
        Uri             = $FullUri
        Method          = $Method
        Headers         = $Headers
        UserAgent       = "PowerShell/5.1 (Windows NT 10.0; Win64; x64) CitrixWEMClient/1.0"
        ContentType     = "application/json; charset=UTF-8"
        ErrorAction     = "Stop"
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
        $ApiSplat['Body'] = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    try {
        $Response = Invoke-WebRequest @ApiSplat
        $JsonContent = $Response.Content | ConvertFrom-Json
        return $JsonContent
    } catch {
        Write-Error "API call to '$($FullUri)' failed. Status: $($_.Exception.Response.StatusCode.value__) - $($_.Exception.Response.StatusDescription)"
        Write-Error "Response content: $($_.Exception.Response.Content)"
        return $null
    }
}
