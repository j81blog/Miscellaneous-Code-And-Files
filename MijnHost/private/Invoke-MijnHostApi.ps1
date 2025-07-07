function Invoke-MijnHostApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('GET', 'PUT', 'POST', 'DELETE', 'PATCH')]
        [string]$Method,

        [Parameter(Mandatory)]
        [uri]$Url,

        [Parameter()]
        [PSCustomObject]$Body,

        [Parameter(Mandatory)]
        [string]$ApiKey
    )

    # Build the request headers
    $headers = @{
        'API-Key'      = $ApiKey
        'Accept'       = 'application/json'
        'Content-Type' = 'application/json'
        'User-Agent'   = 'PowerShell'
    }

    $params = @{
        Uri     = $Url
        Headers = $headers
        Method  = $Method
    }
    Write-Verbose "Invoking API with URL: $($Url)"
    Write-Verbose "Invoking API with Method: $($Method)"
    if ($Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 5
        Write-Verbose "Invoking API with Body: $($Body | ConvertTo-Json -Depth 5)"
    } else {
        Write-Verbose "Invoking API without Body."
    }
    try {
        $response = Invoke-RestMethod @params -ErrorVariable apiError
        Write-Verbose "API Status: $($response.status)"
        Write-Verbose "API Description: $($response.status_description)"
        Write-Verbose "API Response: $($response.data | ConvertTo-Json -Depth 5)"
        if ($response.status -eq 200 -and $null -eq $response.data.PSObject.Properties.Name) {
            Write-Verbose "<null>"
        } elseif ($response.status -eq 200) {
            Write-Output $response.data
        } else {
            Write-Verbose "API Response: $($response | ConvertTo-Json -Depth 5)"
            Write-Error "Unexpected API Response Format"
        }
    } catch {
        $apiError | ForEach-Object { Write-Verbose -Message $_.Message }
        $statusCode = $(try { $_.Exception.Response.StatusCode.value__ } catch { $null })
        switch ($statusCode) {
            400 { Write-Error "400 Bad Request: Check request syntax and parameters." }
            401 { Write-Error "401 Unauthorized: Ensure your API-Key is correct." }
            403 { Write-Error "403 Forbidden: You do not have permission to access this resource." }
            404 { Write-Error "404 Not Found: The requested resource was not found." }
            405 { Write-Error "405 Method Not Allowed: Check if GET is the correct method for this request." }
            429 { Write-Error "429 Too Many Requests: Rate limit exceeded, try again later." }
            500 { Write-Error "500 Internal Server Error: A server issue occurred, consider reporting it." }
            Default { Write-Error "HTTP Error $($statusCode): $($_.Exception.Message)" }
        }
    }
}