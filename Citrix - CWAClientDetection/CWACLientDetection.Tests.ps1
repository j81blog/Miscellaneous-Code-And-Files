#Requires -Modules Pester
<#
.SYNOPSIS
    Pester tests for CWACLientDetection.ps1 — validates Windows and Mac EOL and CVE logic.

.DESCRIPTION
    Dot-sources only the functions from CWACLientDetection.ps1 (skipping the main
    execution block) and uses Mock on Get-Date so tests are deterministic regardless
    of when they run.

    CVE version ranges are sourced from the comments in the script itself, which
    reference the official Citrix security bulletins (CTX article numbers included).

.NOTES
    Run with: Invoke-Pester .\CWACLientDetection.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Dot-source only the function definitions by extracting them without running
    # the script body. We parse the file and invoke just the function blocks.
    $scriptPath = Join-Path $PSScriptRoot "CWACLientDetection.ps1"

    # Extract function definitions by dot-sourcing in a scope where the top-level
    # guard variables are pre-set so the main body exits early / does nothing.
    $scriptContent = Get-Content -Path $scriptPath -Raw

    # Strip the signature block so it doesn't cause parse errors when re-executing
    $scriptContent = $scriptContent -replace '# SIG # Begin signature block[\s\S]*# SIG # End signature block', ''

    # Wrap only the function definitions — use regex to find each function block
    $functionPattern = '(?ms)^function\s+\w[\w-]*\s*\{.*?^\}'
    $functions = [regex]::Matches($scriptContent, $functionPattern)

    $functionScript = $functions | ForEach-Object { $_.Value } | Out-String
    Invoke-Expression $functionScript

    # Stub out Get-LatestCWAWindowsVersionInfo so tests don't hit the internet
    function global:Get-LatestCWAWindowsVersionInfo { return $null }
}

Describe "Test-CWAWindowsVersion — EOL date enforcement" {

    Context "Version 24.9.0.201 — EOL on 2026-05-26" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2026-05-25" }
            $result = Test-CWAWindowsVersion -Version ([Version]"24.9.0.201")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2026-05-26" }
            $result = Test-CWAWindowsVersion -Version ([Version]"24.9.0.201")
            $result.IsEOL | Should -Be $true
        }

        It "Is EOL after the EOL date" {
            Mock Get-Date { return [DateTime]"2027-01-01" }
            $result = Test-CWAWindowsVersion -Version ([Version]"24.9.0.201")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version 24.5.0.131 — EOL on 2026-01-08" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2026-01-07" }
            $result = Test-CWAWindowsVersion -Version ([Version]"24.5.0.131")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2026-01-08" }
            $result = Test-CWAWindowsVersion -Version ([Version]"24.5.0.131")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version 25.3.2.196 — EOL on 2026-11-22" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2026-11-21" }
            $result = Test-CWAWindowsVersion -Version ([Version]"25.3.2.196")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2026-11-22" }
            $result = Test-CWAWindowsVersion -Version ([Version]"25.3.2.196")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version 22.10.5.14 — unconditionally EOL (le threshold)" {
        It "Is always EOL regardless of date" {
            Mock Get-Date { return [DateTime]"2020-01-01" }
            $result = Test-CWAWindowsVersion -Version ([Version]"22.10.5.14")
            $result.IsEOL | Should -Be $true
        }
    }
}

Describe "Test-CWAMacVersion — EOL date enforcement" {

    Context "Version 24.09.0.54 — EOL on 2026-03-16" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2026-03-15" }
            $result = Test-CWAMacVersion -Version ([Version]"24.09.0.54")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2026-03-16" }
            $result = Test-CWAMacVersion -Version ([Version]"24.09.0.54")
            $result.IsEOL | Should -Be $true
        }

        It "Is EOL after the EOL date" {
            Mock Get-Date { return [DateTime]"2027-01-01" }
            $result = Test-CWAMacVersion -Version ([Version]"24.09.0.54")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version 25.05.0.58 — EOL on 2027-01-02" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2027-01-01" }
            $result = Test-CWAMacVersion -Version ([Version]"25.05.0.58")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2027-01-02" }
            $result = Test-CWAMacVersion -Version ([Version]"25.05.0.58")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version 25.11.0.36 — EOL on 2027-06-19" {
        It "Is NOT EOL one day before the EOL date" {
            Mock Get-Date { return [DateTime]"2027-06-18" }
            $result = Test-CWAMacVersion -Version ([Version]"25.11.0.36")
            $result.IsEOL | Should -Be $false
        }

        It "Is EOL on the EOL date" {
            Mock Get-Date { return [DateTime]"2027-06-19" }
            $result = Test-CWAMacVersion -Version ([Version]"25.11.0.36")
            $result.IsEOL | Should -Be $true
        }
    }

    Context "Version below 23.01.0.53 — unconditionally EOL" {
        It "Is always EOL for very old versions" {
            Mock Get-Date { return [DateTime]"2020-01-01" }
            $result = Test-CWAMacVersion -Version ([Version]"22.12.0.0")
            $result.IsEOL | Should -Be $true
        }
    }
}

# ---------------------------------------------------------------------------
# CVE tests — Windows
# Source: script comments referencing Citrix security bulletins
# ---------------------------------------------------------------------------

Describe "Test-CWAWindowsVersion — CVE-2021-22907 (CTX307794)" {
    # Affected: CWA before 2105 (>=19.13.0 <21.5.0) and 1912 LTSR before CU4 (<19.12.4000)

    It "Current-stream 20.x is CVE impacted (>=19.13 <21.5)" {
        $result = Test-CWAWindowsVersion -Version ([Version]"20.12.0")
        $result.IsisCveImpacted | Should -Be $true
        $result.CVEs | Should -Contain "CVE-2021-22907"
    }

    It "Fixed current-stream 21.5.0 is NOT CVE impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"21.5.0")
        $result.CVEs | Should -Not -Contain "CVE-2021-22907"
    }

    It "1912 LTSR CU3 (19.12.3000) is CVE impacted (<19.12.4000)" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.3000")
        $result.IsisCveImpacted | Should -Be $true
        $result.CVEs | Should -Contain "CVE-2021-22907"
    }

    It "1912 LTSR CU4 (19.12.4000) is NOT CVE impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.4000")
        $result.CVEs | Should -Not -Contain "CVE-2021-22907"
    }
}

Describe "Test-CWAWindowsVersion — CVE-2023-24483 / CVE-2023-24484 / CVE-2023-24485 (CTX477616, CTX477617)" {
    # CVE-2023-24483: current <2212 (>=22.04 <22.12.0.48), 2203 LTSR before CU2 (>=19.13 <22.3.2000), 1912 LTSR before CU6 (<19.12.6000.9)
    # CVE-2023-24484/85: same ranges + 1912 LTSR before CU7 HF2 (<19.12.7002)

    It "22.8.0 (between 22.04 and 22.12) is impacted by all three CVEs" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.8.0")
        $result.CVEs | Should -Contain "CVE-2023-24483"
        $result.CVEs | Should -Contain "CVE-2023-24484"
        $result.CVEs | Should -Contain "CVE-2023-24485"
    }

    It "22.12.0.48 (fixed current-stream) is NOT impacted by the 2023 CVE trio" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.12.0.48")
        $result.CVEs | Should -Not -Contain "CVE-2023-24483"
        $result.CVEs | Should -Not -Contain "CVE-2023-24484"
        $result.CVEs | Should -Not -Contain "CVE-2023-24485"
    }

    It "2203 LTSR CU1 (22.3.1000) is impacted by all three CVEs" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.3.1000")
        $result.CVEs | Should -Contain "CVE-2023-24483"
        $result.CVEs | Should -Contain "CVE-2023-24484"
        $result.CVEs | Should -Contain "CVE-2023-24485"
    }

    It "2203 LTSR CU2 (22.3.2000) is NOT impacted by all three CVEs" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.3.2000")
        $result.CVEs | Should -Not -Contain "CVE-2023-24483"
        $result.CVEs | Should -Not -Contain "CVE-2023-24484"
        $result.CVEs | Should -Not -Contain "CVE-2023-24485"
    }

    It "1912 LTSR CU5 (19.12.5000) is impacted by CVE-2023-24483" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.5000")
        $result.CVEs | Should -Contain "CVE-2023-24483"
    }

    It "1912 LTSR CU6 (19.12.6000.9) is NOT impacted by CVE-2023-24483" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.6000.9")
        $result.CVEs | Should -Not -Contain "CVE-2023-24483"
    }

    It "1912 LTSR CU7 HF1 (19.12.7001) is impacted by CVE-2023-24484 and CVE-2023-24485" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.7001")
        $result.CVEs | Should -Contain "CVE-2023-24484"
        $result.CVEs | Should -Contain "CVE-2023-24485"
    }

    It "1912 LTSR CU7 HF2 (19.12.7002) is NOT impacted by CVE-2023-24484 and CVE-2023-24485" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.7002")
        $result.CVEs | Should -Not -Contain "CVE-2023-24484"
        $result.CVEs | Should -Not -Contain "CVE-2023-24485"
    }
}

Describe "Test-CWAWindowsVersion — CVE-2020-13884 / CVE-2020-13885 (CTX275460)" {
    # Affected: CWA for Windows before 1912 (<19.12.0), Receiver before 4.9 CU9 (<4.9.9002)

    It "CWA 19.11.0 (before 1912) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.11.0")
        $result.CVEs | Should -Contain "CVE-2020-13884"
        $result.CVEs | Should -Contain "CVE-2020-13885"
    }

    It "CWA 19.12.0 (1912 release) is NOT impacted by pre-1912 CVEs" {
        $result = Test-CWAWindowsVersion -Version ([Version]"19.12.0")
        $result.CVEs | Should -Not -Contain "CVE-2020-13884"
        $result.CVEs | Should -Not -Contain "CVE-2020-13885"
    }
}

Describe "Test-CWAWindowsVersion — CVE-2024-6286 (CTX678036)" {
    # Affected:
    #   2203.1 LTSR before CU6 HF2 (<22.03.6002.6116)
    #   2403.1 current (>=24.03.0 <24.3.1.97)
    #   2402 LTSR before release (>=22.04.0 <24.2.0.172)

    It "22.03.6001 (2203 LTSR before CU6 HF2) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.3.6001")
        $result.CVEs | Should -Contain "CVE-2024-6286"
    }

    It "22.03.6002.6116 (2203 LTSR CU6 HF2) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"22.3.6002.6116")
        $result.CVEs | Should -Not -Contain "CVE-2024-6286"
    }

    It "24.3.0.93 (2403 before 2403.1) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.3.0.93")
        $result.CVEs | Should -Contain "CVE-2024-6286"
    }

    It "24.3.1.97 (2403.1 fixed) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.3.1.97")
        $result.CVEs | Should -Not -Contain "CVE-2024-6286"
    }

    It "23.2.0.38 (between 22.04 and 24.2.0.172) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"23.2.0.38")
        $result.CVEs | Should -Contain "CVE-2024-6286"
    }

    It "24.2.0.172 (2402 LTSR release, fixed) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.0.172")
        $result.CVEs | Should -Not -Contain "CVE-2024-6286"
    }
}

Describe "Test-CWAWindowsVersion — CVE-2024-7889 / CVE-2024-7890 (CTX691485)" {
    # Affected:
    #   Current before 2405 (>=24.03.0 <24.05.0)
    #   2402 LTSR before CU1 (<24.2.1000.1016)

    It "24.4.0 (between 24.03 and 24.05) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.4.0")
        $result.CVEs | Should -Contain "CVE-2024-7889"
        $result.CVEs | Should -Contain "CVE-2024-7890"
    }

    It "24.5.0 (2405 fixed) is NOT impacted by the 7889/7890 current-stream range" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.5.0")
        $result.CVEs | Should -Not -Contain "CVE-2024-7889"
        $result.CVEs | Should -Not -Contain "CVE-2024-7890"
    }

    It "24.2.0.172 (2402 LTSR, before CU1) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.0.172")
        $result.CVEs | Should -Contain "CVE-2024-7889"
        $result.CVEs | Should -Contain "CVE-2024-7890"
    }

    It "24.2.1000.1016 (2402 LTSR CU1, fixed) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.1000.1016")
        $result.CVEs | Should -Not -Contain "CVE-2024-7889"
        $result.CVEs | Should -Not -Contain "CVE-2024-7890"
    }
}

Describe "Test-CWAWindowsVersion — CVE-2025-4879 (CTX694718)" {
    # Affected:
    #   Current before 2409 (>=24.3.0 <24.9.0)
    #   2402 LTSR before CU2 HF1 (<24.2.2001.3)
    #   2402 LTSR CU3 before HF1 (>=24.2.3000 <24.2.3001.9)

    It "24.5.0 (current-stream, between 24.3 and 24.9) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.5.0")
        $result.CVEs | Should -Contain "CVE-2025-4879"
    }

    It "24.9.0 (2409 fixed) is NOT impacted by the current-stream range" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.9.0")
        $result.CVEs | Should -Not -Contain "CVE-2025-4879"
    }

    It "24.2.2000.0 (2402 LTSR CU2, before HF1) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.2000.0")
        $result.CVEs | Should -Contain "CVE-2025-4879"
    }

    It "24.2.2001.3 (2402 LTSR CU2 HF1, fixed) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.2001.3")
        $result.CVEs | Should -Not -Contain "CVE-2025-4879"
    }

    It "24.2.3000.0 (2402 LTSR CU3, before HF1) is impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.3000.0")
        $result.CVEs | Should -Contain "CVE-2025-4879"
    }

    It "24.2.3001.9 (2402 LTSR CU3 HF1, fixed) is NOT impacted" {
        $result = Test-CWAWindowsVersion -Version ([Version]"24.2.3001.9")
        $result.CVEs | Should -Not -Contain "CVE-2025-4879"
    }
}

# ---------------------------------------------------------------------------
# CVE tests — Mac
# Source: script comments referencing Citrix security bulletins
# ---------------------------------------------------------------------------

Describe "Test-CWAMacVersion — CVE-2024-5027 (CTX675851)" {
    # Affected: CWA for Mac before 2402.10 (<24.02.10)

    It "24.02.9 (before 2402.10) is impacted" {
        $result = Test-CWAMacVersion -Version ([Version]"24.02.9")
        $result.IsisCveImpacted | Should -Be $true
        $result.CVEs | Should -Contain "CVE-2024-5027"
    }

    It "24.02.10 (2402.10 fixed) is NOT impacted" {
        $result = Test-CWAMacVersion -Version ([Version]"24.02.10")
        $result.CVEs | Should -Not -Contain "CVE-2024-5027"
    }

    It "24.09.0.54 (later release) is NOT impacted by CVE-2024-5027" {
        $result = Test-CWAMacVersion -Version ([Version]"24.09.0.54")
        $result.CVEs | Should -Not -Contain "CVE-2024-5027"
    }
}

Describe "Test-CWAMacVersion — CVE-2024-7549 (CTX691484)" {
    # Affected: CWA for Mac before 2409 (<24.09.0.54)

    It "24.05.0.89 (before 2409) is impacted" {
        $result = Test-CWAMacVersion -Version ([Version]"24.05.0.89")
        $result.IsisCveImpacted | Should -Be $true
        $result.CVEs | Should -Contain "CVE-2024-7549"
    }

    It "24.09.0.54 (2409 fixed) is NOT impacted" {
        $result = Test-CWAMacVersion -Version ([Version]"24.09.0.54")
        $result.CVEs | Should -Not -Contain "CVE-2024-7549"
    }

    It "25.05.0.58 (later release) is NOT impacted by CVE-2024-7549" {
        $result = Test-CWAMacVersion -Version ([Version]"25.05.0.58")
        $result.CVEs | Should -Not -Contain "CVE-2024-7549"
    }
}
