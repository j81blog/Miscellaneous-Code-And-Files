
function Get-AzureDevOpsProject {
    <#
    .SYNOPSIS
        Retrieves details of a specified Azure DevOps project.

    .DESCRIPTION
        The Get-AzureDevOpsProject function retrieves details of a specified Azure DevOps project using the Azure DevOps REST API.
        It requires the project name, organization name, and a personal access token (PAT) for authentication.

    .PARAMETER ProjectName
        The name of the Azure DevOps project.

    .PARAMETER Organization
        The name of the Azure DevOps organization.

    .PARAMETER PersonalAccessToken
        The personal access token (PAT) used for authentication.

    .EXAMPLE
        Export-LibraryVariableSets -ProjectName "MyProject" -Organization "MyOrg" -PersonalAccessToken "myPAT"

    .NOTES
        Function : Get-AzureDevOpsProject
        Author   : John Billekens
        Copyright: Copyright (c) John Billekens Consultancy
        Version  : 1.0
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,

        [Parameter(Mandatory = $true)]
        [string]$Organization,

        [Parameter(Mandatory = $true)]
        [Alias("PAT")]
        [string]$PersonalAccessToken
    )
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PersonalAccessToken"))

    $uri = "https://dev.azure.com/$Organization/_apis/projects/$($ProjectName)?api-version=7.1"
    $Headers = @{
        Authorization  = "Basic {0}" -f $base64AuthInfo
        "Content-Type" = "application/json"
    }

    Write-Verbose "Retrieving Project details from $uri"

    # Fetch project details
    try {
        $project = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers
        if (-not $project -or -not $project.id) {
            $project = Invoke-RestMethod -Uri $uri -Method Get -Headers $Headers
            return $project
        }
    } catch {
        Write-Error "Error retrieving project: $_"
        return
    }
}

# SIG # Begin signature block
# MIInZQYJKoZIhvcNAQcCoIInVjCCJ1ICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBAzOEYFuCCYNrG
# 4IqfuVDZgMS7IM+Hl9soo/22UpzeGKCCIBcwggXJMIIEsaADAgECAhAbtY8lKt8j
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
# MIIGgzCCBGugAwIBAgIRAJ6cBPZVqLSnAm1JjGx4jaowDQYJKoZIhvcNAQEMBQAw
# VjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5B
# LjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGluZyAyMDIxIENBMB4XDTI1MDEw
# OTA4NDA0M1oXDTM2MDEwNzA4NDA0M1owUDELMAkGA1UEBhMCUEwxITAfBgNVBAoM
# GEFzc2VjbyBEYXRhIFN5c3RlbXMgUy5BLjEeMBwGA1UEAwwVQ2VydHVtIFRpbWVz
# dGFtcCAyMDI1MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxylfZ/is
# K92QReVAi1jkPzXW25QL0HhjI3wov24m0+9YT5MCleFL0LdTLjsKGlAmLbC4cPI6
# 5jpqM9h6ByisxKYktwNawN7LF1GTJ0q24olaQ4/uTLZ210lRCSm3HLh25sHI5d/T
# eFu9s3HKAv53igLsDtQyfvUjvmJB53EYlfeYnVocUQHA2L+O4XPRhBWbUxcUFy26
# y+DezfdAai5Xt2ss583HBD0PhOh+qdNMxPR1Kfvt22UxeD38j0Zygi3OXswMxKqm
# 21ORf57o8evU9ZptNo5bZRV50zBdb5WpHkF1mKRiI7a0e1j+7SDGZ5O/J62En3gK
# fJXvv1v+fqq+7akGbn1vYp77EU3H5Oz/ppyoyS7km8KoMXpbwga8s/a+dW09OetW
# kdnPo6BcoKlu5+BTwpzCzo+NF+KLe8D9rvJC0Q1R24bB6uUhi6q/A2xateMLNgC0
# t7WGthhogO8F+/a0uaAzJ0mP8ZiTuXLqbkr6qcpczu483CzsFoqgq6tOQF6edUka
# 4/cUbfCnWVqQ3VoVphPDBYhbZkNAKjgyyQZ9YUAMdxbw/6bXuqRNQYpdATlQtkp2
# 3qv9zcpQ8Lw3QIP9AmUSbECGsnR7MCcMmAZWFA8mkCtslEue4aG52Mf70rTL0wfe
# oouIxld1JGYdxr8HQwrGZGyV2lPAExf8+g8CAwEAAaOCAVAwggFMMHUGCCsGAQUF
# BwEBBGkwZzA7BggrBgEFBQcwAoYvaHR0cDovL3N1YmNhLnJlcG9zaXRvcnkuY2Vy
# dHVtLnBsL2N0c2NhMjAyMS5jZXIwKAYIKwYBBQUHMAGGHGh0dHA6Ly9zdWJjYS5v
# Y3NwLWNlcnR1bS5jb20wHwYDVR0jBBgwFoAUvlQCL79AbHNDzqwJJU6eQ0Qa7uAw
# DAYDVR0TAQH/BAIwADA5BgNVHR8EMjAwMC6gLKAqhihodHRwOi8vc3ViY2EuY3Js
# LmNlcnR1bS5wbC9jdHNjYTIwMjEuY3JsMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMI
# MA4GA1UdDwEB/wQEAwIHgDAiBgNVHSAEGzAZMAgGBmeBDAEEAjANBgsqhGgBhvZ3
# AgUBCzAdBgNVHQ4EFgQUgYwGoChT/AA/236eSsEfIuyyEokwDQYJKoZIhvcNAQEM
# BQADggIBAJkPGQwb6wVD52i/OwGHOCZZnx9WT+creuTLc2LvH25rC93d3L2LPhJ2
# 7X7vX9sDHoc0sr3nd0XOfWtODvDTe6ZcOD14O9cH0hODERTNRLqi+t86vbk45v/b
# QO969WgnVppKayqdGi6GaJVDdKhnL6/fkBvFSCVTHLkqhXhL0ayxCitsVZDEnU02
# w4bHlIyOLzfga15uc+ORAN2g6UomULqDXeERZw83XW4H3AkD2mNlMl6szQY57s+g
# Mh5xcyrTZQnr5DAYIeHSA7f9AxhgzmkxAFmbVBKiuQJR3dDwZ3eNC56IOFAE1Nwb
# ehh33g5lhBxU4xyrJp/UPMIho/dOm1YC/N+bXxB/RIGA5JaqzlMVsQ39XDgO3bP6
# /KSHNr4y0PbTkpJvVl1W503ixt0Oe3604Ar0zm3f6n91MxPe50zTlO7zjGRKONQI
# JobhGxrMkCAzP1enyUF9UZ88yTaKn005FM1KD9rZTR5zbIxaNmFfucmXKGmsJjVp
# ke08sFFxtv7xYCWhtG3xKKHXnl6ewOCOB2gw6X0Wu8qYCRD3k8B7gUSaY/Tftcba
# 4vugcxz8LAAL1CZufDxqFbLXhwF8L6YODVYL1JNwSm5e8RbpVlNSh6h/7JO09AhQ
# UOaIbij5hX9aKgD+ADvWt2INsATMBINczzoesW1F7JM7PYkmvchsMIIGuTCCBKGg
# AwIBAgIRAJmjgAomVTtlq9xuhKaz6jkwDQYJKoZIhvcNAQEMBQAwgYAxCzAJBgNV
# BAYTAlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYD
# VQQLEx5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxJDAiBgNVBAMTG0Nl
# cnR1bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0yMTA1MTkwNTMyMThaFw0zNjA1
# MTgwNTMyMThaMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBT
# eXN0ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBDb2RlIFNpZ25pbmcgMjAyMSBD
# QTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ0jzwQwIzvBRiznM3M+
# Y116dbq+XE26vest+L7k5n5TeJkgH4Cyk74IL9uP61olRsxsU/WBAElTMNQI/HsE
# 0uCJ3VPLO1UufnY0qDHG7yCnJOvoSNbIbMpT+Cci75scCx7UsKK1fcJo4TXetu4d
# u2vEXa09Tx/bndCBfp47zJNsamzUyD7J1rcNxOw5g6FJg0ImIv7nCeNn3B6gZG28
# WAwe0mDqLrvU49chyKIc7gvCjan3GH+2eP4mYJASflBTQ3HOs6JGdriSMVoD1lzB
# JobtYDF4L/GhlLEXWgrVQ9m0pW37KuwYqpY42grp/kSYE4BUQrbLgBMNKRvfhQPs
# kDfZ/5GbTCyvlqPN+0OEDmYGKlVkOMenDO/xtMrMINRJS5SY+jWCi8PRHAVxO0xd
# x8m2bWL4/ZQ1dp0/JhUpHEpABMc3eKax8GI1F03mSJVV6o/nmmKqDE6TK34eTAgD
# iBuZJzeEPyR7rq30yOVw2DvetlmWssewAhX+cnSaaBKMEj9O2GgYkPJ16Q5Da1AP
# YO6n/6wpCm1qUOW6Ln1J6tVImDyAB5Xs3+JriasaiJ7P5KpXeiVV/HIsW3ej85A6
# cGaOEpQA2gotiUqZSkoQUjQ9+hPxDVb/Lqz0tMjp6RuLSKARsVQgETwoNQZ8jCeK
# wSQHDkpwFndfCceZ/OfCUqjxAgMBAAGjggFVMIIBUTAPBgNVHRMBAf8EBTADAQH/
# MB0GA1UdDgQWBBTddF1MANt7n6B0yrFu9zzAMsBwzTAfBgNVHSMEGDAWgBS2oVQ5
# AsOgP46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL2NybC5jZXJ0dW0ucGwvY3Ru
# Y2EyLmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYBBQUHMAGGHGh0dHA6Ly9zdWJj
# YS5vY3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKGJmh0dHA6Ly9yZXBvc2l0b3J5
# LmNlcnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQGCCsG
# AQUFBwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEMBQAD
# ggIBAHWIWA/lj1AomlOfEOxD/PQ7bcmahmJ9l0Q4SZC+j/v09CD2csX8Yl7pmJQE
# TIMEcy0VErSZePdC/eAvSxhd7488x/Cat4ke+AUZZDtfCd8yHZgikGuS8mePCHyA
# iU2VSXgoQ1MrkMuqxg8S1FALDtHqnizYS1bIMOv8znyJjZQESp9RT+6NH024/IqT
# RsRwSLrYkbFq4VjNn/KV3Xd8dpmyQiirZdrONoPSlCRxCIi54vQcqKiFLpeBm5S0
# IoDtLoIe21kSw5tAnWPazS6sgN2oXvFpcVVpMcq0C4x/CLSNe0XckmmGsl9z4UUg
# uAJtf+5gE8GVsEg/ge3jHGTYaZ/MyfujE8hOmKBAUkVa7NMxRSB1EdPFpNIpEn/p
# SHuSL+kWN/2xQBJaDFPr1AX0qLgkXmcEi6PFnaw5T17UdIInA58rTu3mefNuzUts
# e4AgYmxEmJDodf8NbVcU6VdjWtz0e58WFZT7tST6EWQmx/OoHPelE77lojq7lpsj
# hDCzhhp4kfsfszxf9g2hoCtltXhCX6NqsqwTT7xe8LgMkH4hVy8L1h2pqGLT2aNC
# x7h/F95/QvsTeGGjY7dssMzq/rSshFQKLZ8lPb8hFTmiGDJNyHga5hZ59IGynk08
# mHhBFM/0MLeBzlAQq1utNjQprztZ5vv/NJy8ua9AGbwkMWkOMIIGuTCCBKGgAwIB
# AgIRAOf/acc7Nc5LkSbYdHxopYcwDQYJKoZIhvcNAQEMBQAwgYAxCzAJBgNVBAYT
# AlBMMSIwIAYDVQQKExlVbml6ZXRvIFRlY2hub2xvZ2llcyBTLkEuMScwJQYDVQQL
# Ex5DZXJ0dW0gQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxJDAiBgNVBAMTG0NlcnR1
# bSBUcnVzdGVkIE5ldHdvcmsgQ0EgMjAeFw0yMTA1MTkwNTMyMDdaFw0zNjA1MTgw
# NTMyMDdaMFYxCzAJBgNVBAYTAlBMMSEwHwYDVQQKExhBc3NlY28gRGF0YSBTeXN0
# ZW1zIFMuQS4xJDAiBgNVBAMTG0NlcnR1bSBUaW1lc3RhbXBpbmcgMjAyMSBDQTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOkSHwQ17bldesWmlUG+imV/
# TnfRbSV102aO2/hhKH9/t4NAoVoipzu0ePujH67y8iwlmWuhqRR4xLeLdPxolEL5
# 5CzgUXQaq+Qzr5Zk7ySbNl/GZloFiYwuzwWS2AVgLPLCZd5DV8QTF+V57Y6lsdWT
# rrl5dEeMfsxhkjM2eOXabwfLy6UH2ZHzAv9bS/SmMo1PobSx+vHWST7c4aiwVRvv
# JY2dWRYpTipLEu/XqQnqhUngFJtnjExqTokt4HyzOsr2/AYOm8YOcoJQxgvc26+L
# AfXHiBkbQkBdTfHak4DP3UlYolICZHL+XSzSXlsRgqiWD4MypWGU4A13xiHmaRBZ
# owS8FET+QAbMiqBaHDM3Y6wohW07yZ/mw9ZKu/KmVIAEBhrXesxifPB+DTyeWNke
# CGq4IlgJr/Ecr1px6/1QPtj66yvXl3uauzPPGEXUk6vUym6nZyE1IGXI45uGVI7X
# qvCt99WuD9LNop9Kd1LmzBGGvxucOo0lj1M3IRi8FimAX3krunSDguC5HgD75nWc
# UgdZVjm/R81VmaDPEP25Wj+C1reicY5CPckLGBjHQqsJe7jJz1CJXBMUtZs10cVK
# MEK3n/xD2ku5GFWhx0K6eFwe50xLUIZD9GfT7s/5/MyBZ1Ep8Q6H+GMuudDwF0mJ
# itk3G8g6EzZprfMQMc3DAgMBAAGjggFVMIIBUTAPBgNVHRMBAf8EBTADAQH/MB0G
# A1UdDgQWBBS+VAIvv0Bsc0POrAklTp5DRBru4DAfBgNVHSMEGDAWgBS2oVQ5AsOg
# P46KvPrU+Bym0ToO/TAOBgNVHQ8BAf8EBAMCAQYwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwMAYDVR0fBCkwJzAloCOgIYYfaHR0cDovL2NybC5jZXJ0dW0ucGwvY3RuY2Ey
# LmNybDBsBggrBgEFBQcBAQRgMF4wKAYIKwYBBQUHMAGGHGh0dHA6Ly9zdWJjYS5v
# Y3NwLWNlcnR1bS5jb20wMgYIKwYBBQUHMAKGJmh0dHA6Ly9yZXBvc2l0b3J5LmNl
# cnR1bS5wbC9jdG5jYTIuY2VyMDkGA1UdIAQyMDAwLgYEVR0gADAmMCQGCCsGAQUF
# BwIBFhhodHRwOi8vd3d3LmNlcnR1bS5wbC9DUFMwDQYJKoZIhvcNAQEMBQADggIB
# ALiTWXfJTBX9lAcIoKd6oCzwQZOfARQkt0OmiQ390yEqMrStHmpfycggfPGlBHdM
# DDYhHDVTGyvY+WIbdsIWpJ1BNRt9pOrpXe8HMR5sOu71AWOqUqfEIXaHWOEs0UWm
# Vs8mJb4lKclOHV8oSoR0p3GCX2tVO+XF8Qnt7E6fbkwZt3/AY/C5KYzFElU7TCeq
# BLuSagmM0X3Op56EVIMM/xlWRaDgRna0hLQze5mYHJGv7UuTCOO3wC1bzeZWdlPJ
# Ow5v4U1/AljsNLgWZaGRFuBwdF62t6hOKs86v+jPIMqFPwxNJN/ou22DqzpP+7Ty
# YNbDocrThlEN9D2xvvtBXyYqA7jhYY/fW9edUqhZUmkUGM++Mvz9lyT/nBdfaKqM
# 5otK0U5H8hCSL4SGfjOVyBWbbZlUIE8X6XycDBRRKEK0q5JTsaZksoKabFAyRKJY
# gtObwS1UPoDGcmGirwSeGMQTJSh+WR5EXZaEWJVA6ZZPBlGvjgjFYaQ0kLq1Oitb
# muXZmX7Z70ks9h/elK0A8wOg8oiNVd3o1bb59ms1QF4OjZ45rkWfsGuz8ctB9/le
# CuKzkx5Rt1WAOsXy7E7pws+9k+jrePrZKw2DnmlNaT19QgX2I+hFtvhC6uOhj/Cg
# jVEA4q1i1OJzpoAmre7zdEg+kZcFIkrDHgokA5mcIMK1MYIGpDCCBqACAQEwajBW
# MQswCQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEu
# MSQwIgYDVQQDExtDZXJ0dW0gQ29kZSBTaWduaW5nIDIwMjEgQ0ECEAgyT5232pFv
# Y+TyozxeXVEwDQYJYIZIAWUDBAIBBQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAA
# oQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4w
# DAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg/9I19gw0mXUGDNEHksHaMeq8
# eAQ7iq/Kadt83CsK/zQwDQYJKoZIhvcNAQEBBQAEggGAwYfhWpRzvu/X6fv0z3aJ
# Xhr4G/sBfFypk2Ues+sMwzV1Ti+4nqdm9mVoqkVDOcOdZ0+cKqGyXJRmHuSw8qvO
# jCTBXTfYNMW+lbrWy2QBFkBW7XoPNt1VIkIcyDpXbIf1fu9pNBmtC51ySmY6G3kX
# yv7+XLqMgmD+PM2LOpa0p+VPk3c/0YT9BDQFu7BFacFXlk1xnyjV4VAk51tS1s+Y
# +7fG3YQ29sRSd1yipoKwHfgYecMT2zGwjQz/WJPVY914GG2ugf1ynjc9Mvg+TtxK
# 5bCgEUDKjs70mv5BBkIcjrDTwpgj3cVdct5yDQFJ9bfoWq3+kWvNaxQWt2UYt79M
# JaKQcdIQqOmNcAHcd4coJe+Kk8/N8DoBnw6HlvR0zuerdKvBvp8VoRxqEh3CwfSx
# HiNFey+q6izp+Ajo75E9qFIWUPCvsJpXli/AH/rUQ7c0lhcunw53fT0aJg3TDW3k
# FiQqVDFgm7sidr2XlFkrQl8WihBNc/OdsM+gnJYdmc1RoYIEBDCCBAAGCSqGSIb3
# DQEJBjGCA/EwggPtAgEBMGswVjELMAkGA1UEBhMCUEwxITAfBgNVBAoTGEFzc2Vj
# byBEYXRhIFN5c3RlbXMgUy5BLjEkMCIGA1UEAxMbQ2VydHVtIFRpbWVzdGFtcGlu
# ZyAyMDIxIENBAhEAnpwE9lWotKcCbUmMbHiNqjANBglghkgBZQMEAgIFAKCCAVcw
# GgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAz
# MjcyMTM1NTlaMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEIM+h3DWd7SvDy4kPojDl
# 2vd7VA8abisj3c8XVOGM+qDVMD8GCSqGSIb3DQEJBDEyBDBd+7s+rA4IanEWEzst
# gAoweGpppzj19aXMr1d8CN0yUuXzZYjsgSDSqdoB/Xna9CswgaAGCyqGSIb3DQEJ
# EAIMMYGQMIGNMIGKMIGHBBTDJbibF/zFAmBhzitxe0UH3ZxqajBvMFqkWDBWMQsw
# CQYDVQQGEwJQTDEhMB8GA1UEChMYQXNzZWNvIERhdGEgU3lzdGVtcyBTLkEuMSQw
# IgYDVQQDExtDZXJ0dW0gVGltZXN0YW1waW5nIDIwMjEgQ0ECEQCenAT2Vai0pwJt
# SYxseI2qMA0GCSqGSIb3DQEBAQUABIICAFRfs09DABBi6wpNlfDYyQZeCLrDN712
# nerkuKVhBUql8CRgrHXpdEaXHXjJdGUFAXcka5sh9aEZbYct9WHNXx/RSIHdAXuX
# ultNoacWlLtVh9o3tPGXG5pX8DqfXjc2zFbcgv+ukUw7KMytuaAvCpdNt8C8nbEm
# 0ftWtdZ3LC1AOC2MPNqnygtrxxjq6trMLANGRmIK1EMFbTy1ZHkvdobQWHMfr6vy
# S/PgkgpVCTKd/nWK4ulP2mS+vXOVBu1VeR7s8hOOnzDurqcpH4vQ6CpuRxs0XAvY
# +3FKTgJAwEl1866aQ/zHJvmyM0saUoTRlsbm8QNQxRD/mpIRtpminkol9k85udAh
# kQgfwtJi2f5HTHnC2u6gcykz0/ZOrosfw/ppIQFjkAVEtTeXfhHL6Xc7kx8Bua0i
# N5AMJBOTpMIu5NXKlcc+AAbVVdACJ1OJTV0BUIbYLghKUEVb0mdqVfTbilXXghaD
# ql6FfAgjLHCAbDChjr4Q6mD5nyI6CBNGOwlYcMLX51lz3f/qIA/QEy97YkgywgP1
# SrtOXJLli1T6l/1fFDrtZT1KsMQk+DA52uPg5AcyuOQBE/u8Z5VqY4x4lHyOrJDI
# tyoI4mGnp7qP1T6bmzmeO4vk/mUbLgwoApWsQvQHy8aKRq2sVhpnALrXds027aUC
# l09wKN9Cv9vt
# SIG # End signature block
