
function Disconnect-WEMApi {
    <#
    .SYNOPSIS
        Disconnects the  Citrix (Cloud) WEM API.
    .DESCRIPTION
        Disconnects the  Citrix (Cloud) WEM API.
    .EXAMPLE
        PS C:\> Disconnect-WEMApi

        Disconnects (removes the bearer token)
    .NOTES
        Version:        1.0
        Author:         John Billekens Consultancy
        Co-Author:      Gemini
        Creation Date:  2025-08-05
    #>
    [CmdletBinding()]
    param()
    $Script:WemApiConnection = [PSCustomObject]@{
        CustomerId  = ""
        BearerToken = ""
        BaseUrl     = "https://eu-api-webconsole.wem.cloud.com"
        WebSession  = $null
        IsOnPrem    = $false
    }

}
