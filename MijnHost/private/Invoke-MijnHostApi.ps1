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

    $params = @{
        Uri         = $Url
        Method      = $Method
        Headers     = @{
            'API-Key' = $ApiKey
            'Accept'  = 'application/json'
        }
        ContentType = 'application/json'
        ErrorAction = 'Stop'
    }

    if ($Body) {
        $params.Body = $Body | ConvertTo-Json -Depth 10
        Write-Verbose "Request body: $($params.Body)"
    }

    Write-Verbose "$Method $Url"

    try {
        $response = Invoke-RestMethod @params
        Write-Verbose "Response: $($response | ConvertTo-Json -Depth 10)"
        return $response.data
    } catch {
        $statusCode = try { $_.Exception.Response.StatusCode.value__ } catch { $null }
        $message = switch ($statusCode) {
            400 { '400 Bad Request: Check request syntax and parameters.' }
            401 { '401 Unauthorized: Ensure your API-Key is correct.' }
            403 { '403 Forbidden: You do not have permission to access this resource.' }
            404 { '404 Not Found: The requested resource was not found.' }
            405 { '405 Method Not Allowed: The HTTP method is not supported for this endpoint.' }
            429 { '429 Too Many Requests: Rate limit exceeded, try again later.' }
            500 { '500 Internal Server Error: A server issue occurred.' }
            default { "HTTP $statusCode`: $($_.Exception.Message)" }
        }
        throw $message
    }
}
