<#
    .SYNOPSIS
        Exports Azure DevOps Library Variable Sets to JSON files.

    .DESCRIPTION
        The Export-LibraryVariableSets function retrieves Library Variable Sets from an Azure DevOps project and exports them to JSON files.
        The function supports exporting all Library Variable Sets into a single file or splitting them into separate files.
        It also ensures the specified export path exists, creating it if necessary.

    .PARAMETER ProjectName
        The name of the Azure DevOps project.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER PersonalAccessToken
        The personal access token (PAT) used for authentication.

    .PARAMETER Path
        The file system path where the JSON files will be saved.

    .PARAMETER LibraryVariableSetName
        (Optional) The name of the Library Variable Set to export. Supports wildcards. Defaults to "*".

    .PARAMETER SplitInSeparateFiles
        (Optional) If specified, each Library Variable Set will be exported to a separate JSON file.

    .EXAMPLE
        Export-LibraryVariableSets -ProjectName "MyProject" -Organization "MyOrg" -PersonalAccessToken "myPAT" -Path "C:\Exports"

    .EXAMPLE
        Export-LibraryVariableSets -ProjectName "MyProject" -Organization "MyOrg" -PersonalAccessToken "myPAT" -Path "C:\Exports" -LibraryVariableSetName "MyLibrarySet"

    .EXAMPLE
        Export-LibraryVariableSets -ProjectName "MyProject" -Organization "MyOrg" -PersonalAccessToken "myPAT" -Path "C:\Exports" -SplitInSeparateFiles

    .NOTES
        Function : Export-LibraryVariableSets
        Author   : John Billekens
        Copyright: Copyright (c) John Billekens Consultancy
        Version  : 1.0
#>
function Export-LibraryVariableSets {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,

        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [Alias("PAT")]
        [string]$PersonalAccessToken,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
        [string]$LibraryVariableSetName = "*",

        [Parameter(Mandatory = $false)]
        [Switch]$SplitInSeparateFiles
    )

    Write-Verbose "Starting: Export-LibraryVariableSets"

    Write-Verbose "Checking if $Path exists"
    if (-not (Test-Path -Path $Path)) {
        Write-Verbose "Creating $Path"
        New-Item -Path $Path -ItemType Directory | Out-Null
        Write-Verbose "Created $Path"
    } else {
        Write-Verbose "$Path already exists"
    }

    $uri = "https://dev.azure.com/$Organization/$ProjectName/_apis/distributedtask/variablegroups?api-version=6.0"
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$personalAccessToken"))
    Write-Verbose "Retrieving LibraryVariableSets from $uri"
    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) }
    Write-Verbose "Retrieved $($response.value.Count) LibraryVariableSets"
    $results = $response.value | Where-Object { $_.name -like "$($LibraryVariableSetName)" }
    Write-Verbose "Found $($results.Count) matching LibraryVariableSets"

    if ($SplitInSeparateFiles) {
        $results | ForEach-Object {
            $fileName = Join-Path -Path $Path -ChildPath "$($_.name).json"
            Write-Verbose "Exporting $($_.name) to $fileName"
            $_ | ConvertTo-Json -Depth 10 | Set-Content -Path $fileName
        }
    } else {
        $filename = Join-Path -Path $Path -ChildPath "LibraryVariableSets.json"
        Write-Verbose "Exporting all LibraryVariableSets to $filename"
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $filename
    }
    Write-Verbose "Finished: Export-LibraryVariableSets"
}

# SIG # Begin signature block
# MIIndQYJKoZIhvcNAQcCoIInZjCCJ2ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBpk2Mw1uTyFdHU
# jGj3fkWKUTpxXIxNdqWaueuysCla6qCCICkwggXJMIIEsaADAgECAhAbtY8lKt8j
# AEkoya49fu0nMA0GCSqGSIb3DQEBDAUAMH4xCzAJBgNVBAYTAlBMMSIwIAYDVQQK
# ExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkxIjAgBgNVBAMTGUNlcnR1bSBUcnVzdGVkIE5l
# dHdvcmsgQ0EwHhcNMjEwNTMxMDY0MzA2WhcNMjkwOTE3MDY0MzA2WjCBgDELMAkG
# A1UEBhMCUEwxIjAgBgNVBAoTGVVuaXpldG8gVGVjaG5vbG9naWVzIFMuQS4xJzAl
# BgNVBAsTHkNlcnR1bSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTEkMCIGA1UEAxMb
# Q2VydHVtIFRydXN0ZWQgTmV0d29yayBDQSAyMIICIjANBgkqhkiG9w0BAQEFAAOC
# Ag8AMIICCgKCAgEAvfl4+ObVgAxknYYblmRnPyI6HnUBfe/7XGeMycxca6mR5rlC
# 5SBLm9qbe7mZXdmbgEvXhEArJ9PoujC7Pgkap0mV7ytAJMKXx6fumyXvqAoAl4Va
# qp3cKcniNQfrcE1K1sGzVrihQTib0fsxf4/gX+GxPw+OFklg1waNGPmqJhCrKtPQ
# 0WeNG0a+RzDVLnLRxWPa52N5RH5LYySJhi40PylMUosqp8DikSiJucBb+R3Z5yet
# /5oCl8HGUJKbAiy9qbk0WQq/hEr/3/6zn+vZnuCYI+yma3cWKtvMrTscpIfcRnNe
# GWJoRVfkkIJCu0LW8GHgwaM9ZqNd9BjuiMmNF0UpmTJ1AjHuKSbIawLmtWJFfzcV
# WiNoidQ+3k4nsPBADLxNF8tNorMe0AZa3faTz1d1mfX6hhpneLO/lv403L3nUlbl
# s+V1e9dBkQXcXWnjlQ1DufyDljmVe2yAWk8TcsbXfSl6RLpSpCrVQUYJIP4ioLZb
# MI28iQzV13D4h1L92u+sUS4Hs07+0AnacO+Y+lbmbdu1V0vc5SwlFcieLnhO+Nqc
# noYsylfzGuXIkosagpZ6w7xQEmnYDlpGizrrJvojybawgb5CAKT41v4wLsfSRvbl
# jnX98sy50IdbzAYQYLuDNbdeZ95H7JlI8aShFf6tjGKOOVVPORa5sWOd/7cCAwEA
# AaOCAT4wggE6MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLahVDkCw6A/joq8
# +tT4HKbROg79MB8GA1UdIwQYMBaAFAh2zcsH/yT2xc3tu5C84oQ3RnX3MA4GA1Ud
# DwEB/wQEAwIBBjAvBgNVHR8EKDAmMCSgIqAghh5odHRwOi8vY3JsLmNlcnR1bS5w
# bC9jdG5jYS5jcmwwawYIKwYBBQUHAQEEXzBdMCgGCCsGAQUFBzABhhxodHRwOi8v
# c3ViY2Eub2NzcC1jZXJ0dW0uY29tMDEGCCsGAQUFBzAChiVodHRwOi8vcmVwb3Np
# dG9yeS5jZXJ0dW0ucGwvY3RuY2EuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQG
# CCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEM
# BQADggEBAFHCoVgWIhCL/IYx1MIy01z4S6Ivaj5N+KsIHu3V6PrnCA3st8YeDrJ1
# BXqxC/rXdGoABh+kzqrya33YEcARCNQOTWHFOqj6seHjmOriY/1B9ZN9DbxdkjuR
# mmW60F9MvkyNaAMQFtXx0ASKhTP5N+dbLiZpQjy6zbzUeulNndrnQ/tjUoCFBMQl
# lVXwfqefAcVbKPjgzoZwpic7Ofs4LphTZSJ1Ldf23SIikZbr3WjtP6MZl9M7JYjs
# NhI9qX7OAo0FmpKnJ25FspxihjcNpDOO16hO0EoXQ0zF8ads0h5YbBRRfopUofbv
# n3l6XYGaFpAP4bvxSgD5+d2+7arszgowggZFMIIELaADAgECAhAIMk+dt9qRb2Pk
# 8qM8Xl1RMA0GCSqGSIb3DQEBCwUAMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhB
# c3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNp
# Z25pbmcgMjAyMSBDQTAeFw0yNDA0MDQxNDA0MjRaFw0yNzA0MDQxNDA0MjNaMGsx
# CzAJBgNVBAYTAk5MMRIwEAYDVQQHDAlTY2hpam5kZWwxIzAhBgNVBAoMGkpvaG4g
# QmlsbGVrZW5zIENvbnN1bHRhbmN5MSMwIQYDVQQDDBpKb2huIEJpbGxla2VucyBD
# b25zdWx0YW5jeTCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAMslntDb
# SQwHZXwFhmibivbnd0Qfn6sqe/6fos3pKzKxEsR907RkDMet2x6RRg3eJkiIr3TF
# PwqBooyXXgK3zxxpyhGOcuIqyM9J28DVf4kUyZHsjGO/8HFjrr3K1hABNUszP0o7
# H3o6J31eqV1UmCXYhQlNoW9FOmRC1amlquBmh7w4EKYEytqdmdOBavAD5Xq4vLPx
# NP6kyA+B2YTtk/xM27TghtbwFGKnu9Vwnm7dFcpLxans4ONt2OxDQOMA5NwgcUv/
# YTpjhq9qoz6ivG55NRJGNvUXsM3w2o7dR6Xh4MuEGrTSrOWGg2A5EcLH1XqQtkF5
# cZnAPM8W/9HUp8ggornWnFVQ9/6Mga+ermy5wy5XrmQpN+x3u6tit7xlHk1Hc+4X
# Y4a4ie3BPXG2PhJhmZAn4ebNSBwNHh8z7WTT9X9OFERepGSytZVeEP7hgyptSLcu
# hpwWeR4QdBb7dV++4p3PsAUQVHFpwkSbrRTv4EiJ0Lcz9P1HPGFoHiFAQQIDAQAB
# o4IBeDCCAXQwDAYDVR0TAQH/BAIwADA9BgNVHR8ENjA0MDKgMKAuhixodHRwOi8v
# Y2NzY2EyMDIxLmNybC5jZXJ0dW0ucGwvY2NzY2EyMDIxLmNybDBzBggrBgEFBQcB
# AQRnMGUwLAYIKwYBBQUHMAGGIGh0dHA6Ly9jY3NjYTIwMjEub2NzcC1jZXJ0dW0u
# Y29tMDUGCCsGAQUFBzAChilodHRwOi8vcmVwb3NpdG9yeS5jZXJ0dW0ucGwvY2Nz
# Y2EyMDIxLmNlcjAfBgNVHSMEGDAWgBTddF1MANt7n6B0yrFu9zzAMsBwzTAdBgNV
# HQ4EFgQUO6KtBpOBgmrlANVAnyiQC6W6lJwwSwYDVR0gBEQwQjAIBgZngQwBBAEw
# NgYLKoRoAYb2dwIFAQQwJzAlBggrBgEFBQcCARYZaHR0cHM6Ly93d3cuY2VydHVt
# LnBsL0NQUzATBgNVHSUEDDAKBggrBgEFBQcDAzAOBgNVHQ8BAf8EBAMCB4AwDQYJ
# KoZIhvcNAQELBQADggIBAEQsN8wgPMdWVkwHPPTN+jKpdns5AKVFjcn00psf2NGV
# VgWWNQBIQc9lEuTBWb54IK6Ga3hxQRZfnPNo5HGl73YLmFgdFQrFzZ1lnaMdIcyh
# 8LTWv6+XNWfoyCM9wCp4zMIDPOs8LKSMQqA/wRgqiACWnOS4a6fyd5GUIAm4Cuap
# tpFYr90l4Dn/wAdXOdY32UhgzmSuxpUbhD8gVJUaBNVmQaRqeU8y49MxiVrUKJXd
# e1BCrtR9awXbqembc7Nqvmi60tYKlD27hlpKtj6eGPjkht0hHEsgzU0Fxw7ZJghY
# G2wXfpF2ziN893ak9Mi/1dmCNmorGOnybKYfT6ff6YTCDDNkod4egcMZdOSv+/Qv
# +HAeIgEvrxE9QsGlzTwbRtbm6gwYYcVBs/SsVUdBn/TSB35MMxRhHE5iC3aUTkDb
# ceo/XP3uFhVL4g2JZHpFfCSu2TQrrzRn2sn07jfMvzeHArCOJgBW1gPqR3WrJ4hU
# xL06Rbg1gs9tU5HGGz9KNQMfQFQ70Wz7UIhezGcFcRfkIfSkMmQYYpsc7rfzj+z0
# ThfDVzzJr2dMOFsMlfj1T6l22GBq9XQx0A4lcc5Fl9pRxbOuHHWFqIBD/BCEhwni
# OCySzqENd2N+oz8znKooSISStnkNaYXt6xblJF2dx9Dn89FK7d1IquNxOwt0tI5d
# MIIGlTCCBH2gAwIBAgIQCcXM+LtmfXE3qsFZgAbLMTANBgkqhkiG9w0BAQwFADBW
# MQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MSQwIgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0EwHhcNMjMxMTAy
# MDgzMjIzWhcNMzQxMDMwMDgzMjIzWjBQMQswCQYDVQQGEwJQTDEhMB8GA1UECgwY
# QXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMR4wHAYDVQQDDBVDZXJ0dW0gVGltZXN0
# YW1wIDIwMjMwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC5Frrqxud9
# kjaqgkAo85Iyt6ecN343OWPztNOFkORvsc6ukhucOOQQ+szxH0jsi3ARjBwG1b9o
# QwnDx1COOkOpwm2HzY2zxtJe2X2qC+H8DMt4+nUNAYFuMEMjReq5ptDTI3JidDEb
# gcxKdr2azfCwmJ3FpqGpKr1LbtCD2Y7iLrwZOxODkdVYKEyJL0UPJ2A18JgNR54+
# CZ0/pVfCfbOEZag65oyU3A33ZY88h5mhzn9WIPF/qLR5qt9HKe9u8Y+uMgz8MKQa
# gH/ajWG/uYcqeQK28AS3Eh5AcSwl4xFfwHGaFwExxBWSXLZRGUbn9aFdirSZKKde
# 20p1COlmZkxImJY+bxQYSgw5nEM0jPg6rePD+0IQQc4APK6dSHAOQS3QvBJrfzTW
# lCQokGtOvxcNIs5cOvaANmTcGcLgkH0eHgMBpLFlcyzE0QkY8Heh+xltZFEiAvK5
# gbn8CHs8oo9o0/JjLqdWYLrW4HnES43/NC1/sOaCVmtslTaFoW/WRRbtJaRrK/03
# jFjrN921dCntRRinB/Ew3MQ1kxPN604WCMeLvAOpT3F5KbBXoPDrMoW9OGTYnYqv
# 88A6hTbVFRs+Ei8UJjk4IlfOknHWduimRKQ4LYDY1GDSA33YUZ/c3Pootanc2iWP
# Navjy/ieDYIdH8XVbRfWqchnDpTE+0NFcwIDAQABo4IBYzCCAV8wDAYDVR0TAQH/
# BAIwADAdBgNVHQ4EFgQUx2k8Lua941lH/xkSwdk06EHP448wHwYDVR0jBBgwFoAU
# vlQCL79AbHNDzqwJJU6eQ0Qa7uAwDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMDMGA1UdHwQsMCowKKAmoCSGImh0dHA6Ly9jcmwuY2VydHVt
# LnBsL2N0c2NhMjAyMS5jcmwwbwYIKwYBBQUHAQEEYzBhMCgGCCsGAQUFBzABhhxo
# dHRwOi8vc3ViY2Eub2NzcC1jZXJ0dW0uY29tMDUGCCsGAQUFBzAChilodHRwOi8v
# cmVwb3NpdG9yeS5jZXJ0dW0ucGwvY3RzY2EyMDIxLmNlcjBBBgNVHSAEOjA4MDYG
# CyqEaAGG9ncCBQELMCcwJQYIKwYBBQUHAgEWGWh0dHBzOi8vd3d3LmNlcnR1bS5w
# bC9DUFMwDQYJKoZIhvcNAQEMBQADggIBAHjd7rE6Q+b32Ws4vTJeC0HcGDi7mfQU
# nbaJ9nFFOQpizPX+YIpHuK89TPkOdDF7lOEmTZzVQpw0kwpIZDuB8lSM0Gw9KloO
# vXIsGjF/KgTNxYM5aViQNMtoIiF6W9ysmubDHF7lExSToPd1r+N0zYGXlE1uEX4o
# 988K/Z7kwgE/GC649S1OEZ5IGSGmirtcruLX/xhjIDA5S/cVfz0We/ElHamHs+Uf
# W3/IxTigvvq4JCbdZHg9DsjkW+UgGGAVtkxB7qinmWJamvdwpgujAwOT1ym/giPT
# W5C8/MnkL18ZgVQ38sqKqFdqUS+ZIVeXKfV58HaWtV2Lip1Y0luL7Mswb856jz7z
# XINk79H4XfbWOryf7AtWBjrus28jmHWK3gXNhj2StVcOI48Dc6CFfXDMo/c/E/ab
# 217kTYhiht2rCWeGS5THQ3bZVx+lUPLaDe3kVXjYvxMYQKWu04QX6+vURFSeL3WV
# rUSO6nEnZu7X2EYci5MUmmUdEEiAVZO/03yLlNWUNGX72/949vU+5ZN9r9EGdp7X
# 3W7mLL1Tx4gLmHnrB97O+e9RYK6370MC52siufu11p3n8OG5s2zJw2J6LpD+HLby
# CgfRId9Q5UKgsj0A1QuoBut8FI6YdaH3sR1ponEv6GsNYrTyBtSR77csUWLUCyVb
# osF3+ae0+SofMIIGuTCCBKGgAwIBAgIRAJmjgAomVTtlq9xuhKaz6jkwDQYJKoZI
# hvcNAQEMBQAwgYAxCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hu
# b2xvZ2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRo
# b3JpdHkxJDAiBgNVBAMTG0NlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0y
# MTA1MTkwNTMyMThaFw0zNjA1MTgwNTMyMThaMFYxCzAJBgNVBAYTAlBMMSEwHwYD
# VQQKExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBD
# b2RlIFNpZ25pbmcgMjAyMSBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAJ0jzwQwIzvBRiznM3M+Y116dbq+XE26vest+L7k5n5TeJkgH4Cyk74IL9uP
# 61olRsxsU/WBAElTMNQI/HsE0uCJ3VPLO1UufnY0qDHG7yCnJOvoSNbIbMpT+Cci
# 75scCx7UsKK1fcJo4TXetu4du2vEXa09Tx/bndCBfp47zJNsamzUyD7J1rcNxOw5
# g6FJg0ImIv7nCeNn3B6gZG28WAwe0mDqLrvU49chyKIc7gvCjan3GH+2eP4mYJAS
# flBTQ3HOs6JGdriSMVoD1lzBJobtYDF4L/GhlLEXWgrVQ9m0pW37KuwYqpY42grp
# /kSYE4BUQrbLgBMNKRvfhQPskDfZ/5GbTCyvlqPN+0OEDmYGKlVkOMenDO/xtMrM
# INRJS5SY+jWCi8PRHAVxO0xdx8m2bWL4/ZQ1dp0/JhUpHEpABMc3eKax8GI1F03m
# SJVV6o/nmmKqDE6TK34eTAgDiBuZJzeEPyR7rq30yOVw2DvetlmWssewAhX+cnSa
# aBKMEj9O2GgYkPJ16Q5Da1APYO6n/6wpCm1qUOW6Ln1J6tVImDyAB5Xs3+Jriasa
# iJ7P5KpXeiVV/HIsW3ej85A6cGaOEpQA2gotiUqZSkoQUjQ9+hPxDVb/Lqz0tMjp
# 6RuLSKARsVQgETwoNQZ8jCeKwSQHDkpwFndfCceZ/OfCUqjxAgMBAAGjggFVMIIB
# UTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTddF1MANt7n6B0yrFu9zzAMsBw
# zTAfBgNVHSMEGDAWgBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMC
# AQYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDov
# L2NybC5jZXJ0dW0ucGwvY3RuY2EyLmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYB
# BQUHMAGGHGh0dHA6Ly9zdWJjYS5vY3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKG
# Jmh0dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQy
# MDAwLgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9D
# UFMwDQYJKoZIhvcNAQEMBQADggIBAHWIWA/lj1AomlOfEOxD/PQ7bcmahmJ9l0Q4
# SZC+j/v09CD2csX8Yl7pmJQETIMEcy0VErSZePdC/eAvSxhd7488x/Cat4ke+AUZ
# ZDtfCd8yHZgikGuS8mePCHyAiU2VSXgoQ1MrkMuqxg8S1FALDtHqnizYS1bIMOv8
# znyJjZQESp9RT+6NH024/IqTRsRwSLrYkbFq4VjNn/KV3Xd8dpmyQiirZdrONoPS
# lCRxCIi54vQcqKiFLpeBm5S0IoDtLoIe21kSw5tAnWPazS6sgN2oXvFpcVVpMcq0
# C4x/CLSNe0XckmmGsl9z4UUguAJtf+5gE8GVsEg/ge3jHGTYaZ/MyfujE8hOmKBA
# UkVa7NMxRSB1EdPFpNIpEn/pSHuSL+kWN/2xQBJaDFPr1AX0qLgkXmcEi6PFnaw5
# T17UdIInA58rTu3mefNuzUtse4AgYmxEmJDodf8NbVcU6VdjWtz0e58WFZT7tST6
# EWQmx/OoHPelE77lojq7lpsjhDCzhhp4kfsfszxf9g2hoCtltXhCX6NqsqwTT7xe
# 8LgMkH4hVy8L1h2pqGLT2aNCx7h/F95/QvsTeGGjY7dssMzq/rSshFQKLZ8lPb8h
# FTmiGDJNyHga5hZ59IGynk08mHhBFM/0MLeBzlAQq1utNjQprztZ5vv/NJy8ua9A
# GbwkMWkOMIIGuTCCBKGgAwIBAgIRAOf/acc7Nc5LkSbYdHxopYcwDQYJKoZIhvcN
# AQEMBQAwgYAxCzAJBgNVBAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xv
# Z2llcyBTLkEuMScwJQYDVQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkxJDAiBgNVBAMTG0NlcnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0yMTA1
# MTkwNTMyMDdaFw0zNjA1MTgwNTMyMDdaMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQK
# ExhBc3NlY28gRGF0YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1l
# c3RhbXBpbmcgMjAyMSBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AOkSHwQ17bldesWmlUG+imV/TnfRbSV102aO2/hhKH9/t4NAoVoipzu0ePujH67y
# 8iwlmWuhqRR4xLeLdPxolEL55CzgUXQaq+Qzr5Zk7ySbNl/GZloFiYwuzwWS2AVg
# LPLCZd5DV8QTF+V57Y6lsdWTrrl5dEeMfsxhkjM2eOXabwfLy6UH2ZHzAv9bS/Sm
# Mo1PobSx+vHWST7c4aiwVRvvJY2dWRYpTipLEu/XqQnqhUngFJtnjExqTokt4Hyz
# Osr2/AYOm8YOcoJQxgvc26+LAfXHiBkbQkBdTfHak4DP3UlYolICZHL+XSzSXlsR
# gqiWD4MypWGU4A13xiHmaRBZowS8FET+QAbMiqBaHDM3Y6wohW07yZ/mw9ZKu/Km
# VIAEBhrXesxifPB+DTyeWNkeCGq4IlgJr/Ecr1px6/1QPtj66yvXl3uauzPPGEXU
# k6vUym6nZyE1IGXI45uGVI7XqvCt99WuD9LNop9Kd1LmzBGGvxucOo0lj1M3IRi8
# FimAX3krunSDguC5HgD75nWcUgdZVjm/R81VmaDPEP25Wj+C1reicY5CPckLGBjH
# QqsJe7jJz1CJXBMUtZs10cVKMEK3n/xD2ku5GFWhx0K6eFwe50xLUIZD9GfT7s/5
# /MyBZ1Ep8Q6H+GMuudDwF0mJitk3G8g6EzZprfMQMc3DAgMBAAGjggFVMIIBUTAP
# BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBS+VAIvv0Bsc0POrAklTp5DRBru4DAf
# BgNVHSMEGDAWgBS2oVQ5AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYw
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL2Ny
# bC5jZXJ0dW0ucGwvY3RuY2EyLmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYBBQUH
# MAGGHGh0dHA6Ly9zdWJjYS5vY3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKGJmh0
# dHA6Ly9yZXBvc2l0b3J5LmNlcnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQyMDAw
# LgYEVR0gADAmMCQGCCsGAQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMw
# DQYJKoZIhvcNAQEMBQADggIBALiTWXfJTBX9lAcIoKd6oCzwQZOfARQkt0OmiQ39
# 0yEqMrStHmpfycggfPGlBHdMDDYhHDVTGyvY+WIbdsIWpJ1BNRt9pOrpXe8HMR5s
# Ou71AWOqUqfEIXaHWOEs0UWmVs8mJb4lKclOHV8oSoR0p3GCX2tVO+XF8Qnt7E6f
# bkwZt3/AY/C5KYzFElU7TCeqBLuSagmM0X3Op56EVIMM/xlWRaDgRna0hLQze5mY
# HJGv7UuTCOO3wC1bzeZWdlPJOw5v4U1/AljsNLgWZaGRFuBwdF62t6hOKs86v+jP
# IMqFPwxNJN/ou22DqzpP+7TyYNbDocrThlEN9D2xvvtBXyYqA7jhYY/fW9edUqhZ
# UmkUGM++Mvz9lyT/nBdfaKqM5otK0U5H8hCSL4SGfjOVyBWbbZlUIE8X6XycDBRR
# KEK0q5JTsaZksoKabFAyRKJYgtObwS1UPoDGcmGirwSeGMQTJSh+WR5EXZaEWJVA
# 6ZZPBlGvjgjFYaQ0kLq1OitbmuXZmX7Z70ks9h/elK0A8wOg8oiNVd3o1bb59ms1
# QF4OjZ45rkWfsGuz8ctB9/leCuKzkx5Rt1WAOsXy7E7pws+9k+jrePrZKw2DnmlN
# aT19QgX2I+hFtvhC6uOhj/CgjVEA4q1i1OJzpoAmre7zdEg+kZcFIkrDHgokA5mc
# IMK1MYIGojCCBp4CAQEwajBWMQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNv
# IERhdGEgU3lzdGVtcyBTLkEuMSQwIgYDVQQDExtDZXJ0dW0gQ29kZSBTaWduaW5n
# IDIwMjEgQ0ECEAgyT5232pFvY+TyozxeXVEwDQYJYIZIAWUDBAIBBQCggYQwGAYK
# KwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# UO19gYKbYe+ShgwyEL/p1TUSEdDkoJKGWrVDhfMTXQowDQYJKoZIhvcNAQEBBQAE
# ggGARqzbCFbQopiTwerDUYX16hUq3ruQo3KbC2UZfLPmvXum+ZfgjoJozT0B92Wa
# 6O9Kq2qsAJcLlQjUUYRyhzbJ2EF4+d1CSB7CSTRO0qqtg8RmlCrHpgG8pb2pXkN2
# UR/LvPpir9Jde/WSK7PFveMgwFw0jkpf130gTSXA69NliUbJwuMBT8mchTrEm0cU
# DBHE7MvNNQ0YRntYqE2kva1bAK1DdfaUGkrDwpF1ZRnq4/jQwwsPlOc19NrDwRkI
# kDwNKSxXOZzcRg8N1O7nMS/gsJQS3apvgOj3F9o0RYVzpGZulVpqTSz2LPgbD1TG
# 1fqlnJwAk2+mtwpizLxuqsDbjXXFC6g90Lk1SuAqLJnpr/0KQ9InJ2DSUL5jgOCi
# 0ratXwibRV1FX7eXf1aLslNboyVWd0OF2YFQo7Wd79DRTnzUSqoKVBIzvOMpjd4A
# f1CC1IyAY9eifnVBpJ9tW1Z2upQGLrwlmYxA2KZyg2ek7XUzKJY9TQrSKl+Z5WMM
# +qI/oYIEAjCCA/4GCSqGSIb3DQEJBjGCA+8wggPrAgEBMGowVjELMAkGA1UEBhMC
# UEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMb
# Q2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBAhAJxcz4u2Z9cTeqwVmABssxMA0G
# CWCGSAFlAwQCAgUAoIIBVjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJ
# KoZIhvcNAQkFMQ8XDTI0MTIxMjEwNDExNVowNwYLKoZIhvcNAQkQAi8xKDAmMCQw
# IgQg6pVLsdBAtDFASNhln49hXYh0LMzgZ5LgVgJNSwA60xwwPwYJKoZIhvcNAQkE
# MTIEMIP1aW3wB1YYg635gbis9LYdcSOdE3YkvcZ8x78tfyyN1NW9FXNHh0rGf/GZ
# 8xEjNTCBnwYLKoZIhvcNAQkQAgwxgY8wgYwwgYkwgYYEFA9PuFUe/9j23n9nJrQ8
# E9Bqped3MG4wWqRYMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0
# YSBTeXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAy
# MSBDQQIQCcXM+LtmfXE3qsFZgAbLMTANBgkqhkiG9w0BAQEFAASCAgCloNuIBG91
# cnpEvy7hGJcplut8IG5m4kixqDTiyzp93i5h/Yvd3C2x7u+fxjsG6k0VwETE4W93
# 9vGe8uF8K120uLH44SlkWyIJKpEhYe/WxaiRjoTI1HQcm9JvH33uVV7fUMGkJQeB
# Zx2kSJ5BxOeDznCClGRZGvfGVBNC8p13n4aZExnKyXNul1uXkgukE8xq/9UvhZv3
# UI9jovMJTu6ByVwcwUsEApUxd6jHkplrpsh5Vsi4eL0DbYK/FdSasnuTdbDi/Z1P
# 5Tft7VMVvLtwYn5eh2ayx1s7gERRu2IKoDdhXt3iFXcp2F5pF5h3LBJ3j4RlWclU
# c3cuaMC16L+5QBYVlQE8KoQm+1sUgcIIkKVnK1Z39DmRaJKhK86sPqKyqeaBFj8G
# BFNskEhs69JxbgBoGW/e+9tzxiwdsJPdPqgfr5TD6RJE/VY2rJvMekCSS37wcYyB
# XuDTpfJLDySXJMbvjzab3uNWOpESNblEScavAB/92pZIurVeME5c1j+kLH2FNy3e
# wxPlZTrS4Li/bsVmxfQ3RoJPNTpRqSYkBuOM348dCO/mXLPFcRCOTJq1HG12N4pF
# ycL2AyG2lLpDMAOUCvHO+Azbnp/pyyyA32o+EkZA/dtP9yi6wankQozzlrLtIU7w
# pE03FXBwM5nO+/hmupFN7JMNYS6yfjVBhQ==
# SIG # End signature block
