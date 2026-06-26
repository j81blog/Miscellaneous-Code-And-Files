<#
.SYNOPSIS
    Standalone, self-contained interactive selection helpers extracted from AGSW.

.DESCRIPTION
    Drop this file into a new project (or dot-source it) to get an interactive,
    paged console selection menu.

      . .\temp_SelectList.ps1

    Public functions:
      - Read-Choice  : paged single-choice menu over a string[] (Yes/No, Skip, etc.)
                       Returns the chosen string (alias: Show-SelectList).
      - Select-Item  : feed it an object/array and pick an entry, returning the
                       originally selected object (alias: Select-FromObject).

    Internal:
      - Write-InformationColored : colored host output that honors $InformationPreference

    Rendering: by default the menu repaints IN PLACE (it does not wipe the console),
    so any context you printed above the prompt is preserved. Use -ClearScreen for
    the old full-screen behavior.

.NOTES
    Requires PowerShell 5.0+.
#>

#Requires -Version 5.0

function Write-InformationColored {
    <#
    .SYNOPSIS
        Writes messages to the information stream
    .DESCRIPTION
        An alternative to Write-Host which will write to the information stream
        and the host (optionally in colors specified) but will honor the
        $InformationPreference of the calling context.
    .NOTES
        Source: https://blog.kieranties.com/2018/03/26/write-information-with-colours
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory, Position = 0)]
        [Alias("Message")]
        [Object]$MessageData,

        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor,

        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,

        [Switch]$NoNewline
    )
    $messageData = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }
    Write-Information -MessageData $messageData -InformationAction Continue | Out-Host
}

function Read-Choice {
    <#
    .SYNOPSIS
        Displays a paged, interactive single-choice menu and returns the chosen string.
    .DESCRIPTION
        Renders the supplied string array as a numbered, paginated list and prompts the
        user to pick one. Supports optional/required selection, an extra "Skip" entry,
        a simplified Yes/No mode, and an extra free-text block above or below the prompt.

        By default the menu repaints in place between renders (invalid input, paging)
        WITHOUT clearing the console, so any output above the prompt is preserved.
        Pass -ClearScreen to clear the whole console on each render instead.
    .PARAMETER Items
        Non-empty array of option strings to choose from.
    .PARAMETER PromptText
        Heading shown above the option list.
    .PARAMETER Required
        Selection cannot be skipped.
    .PARAMETER AddSkip
        Adds an explicit "0. Skip" option (only valid when not Required).
    .PARAMETER YesNo
        Treat the single supplied item as a Yes/No question; returns [bool].
    .PARAMETER TextBlock
        Extra informational text rendered with the prompt.
    .PARAMETER TextBlockBefore
        Render TextBlock above the prompt instead of below it.
    .PARAMETER NoNextPageOnEnter
        Do not treat [Enter] as "next page".
    .PARAMETER ClearScreen
        Clear the entire console (Clear-Host) on each render. Off by default; the menu
        repaints in place so surrounding console output is kept.
    .PARAMETER NoClearScreen
        Deprecated / no-op. In-place rendering is now the default; kept for backwards
        compatibility so existing callers don't break.
    .PARAMETER SkipText
        Label for the Skip option.
    .PARAMETER MaxItemsPerPage
        Items shown per page (1-50).
    .OUTPUTS
        The selected string, $true/$false (YesNo), or $null when skipped.
    #>
    [CmdletBinding(DefaultParameterSetName = 'MPC')]
    [OutputType([string], [bool])]
    param(
        [Parameter(ParameterSetName = 'MPC', Mandatory = $true)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $true)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $true)]
        [ValidateScript({
                if (-not $_ -or -not $_.Count -or $_.Count -eq 0) {
                    throw "Items must be a non-empty array"
                } else {
                    $true
                }
            })]
        [string[]]$Items,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [String]$PromptText = 'Select an option from the list below',

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $false)]
        [Switch]$Required,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Switch]$AddSkip,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $true)]
        [Switch]$YesNo,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $false)]
        [String]$TextBlock,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $false)]
        [Switch]$TextBlockBefore,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Switch]$NoNextPageOnEnter,

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $false)]
        [Switch]$ClearScreen,

        # Deprecated: in-place rendering is the default now. Kept so old callers work.
        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [Parameter(ParameterSetName = 'YesNo', Mandatory = $false)]
        [Switch]$NoClearScreen,

        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [ValidateScript({ if ($AddSkip -and [string]::IsNullOrEmpty($_)) { throw "When using the 'AddSkip' option, 'SkipText' cannot be empty. Provide a non-empty value for 'SkipText'." } else { return $true } })]
        [string]$SkipText = 'Skip',

        [Parameter(ParameterSetName = 'MPC', Mandatory = $false)]
        [Parameter(ParameterSetName = 'MPCSkip', Mandatory = $false)]
        [ValidateRange(1, 50)]
        [int]$MaxItemsPerPage = 18
    )

    if ($YesNo) {
        Write-Verbose "YesNo switch is enabled, nr of items: $($Items.Count)"
        if ($Items.Count -gt 1) {
            Write-Error "The 'YesNo' switch requires exactly one item. Please provide a single item in the 'Items' array."
            return
        }
        $promptText = "Yes/No: $($Items[0])"
        $yesNoItems = 'Yes', 'No'

        $selection = Read-Choice -Items $yesNoItems -PromptText $promptText -Required -ClearScreen:$ClearScreen
        if ($selection -ieq 'Yes') {
            return $true
        } else {
            return $false
        }
    } else {

        # Adjust $MaxItemsPerPage if AddSkip is enabled
        if (-not $Required -and $AddSkip) {
            Write-Verbose "Adjusting MaxItemsPerPage to $($MaxItemsPerPage - 1) due to AddSkip option."
            $MaxItemsPerPage--
        }

        $currentPage = 1
        $totalPages = [math]::Ceiling($Items.Count / $MaxItemsPerPage)
        $errorText = ""
        $pages = $totalPages -gt 1

        # In-place repaint: remember where drawing starts so we can rewind the cursor
        # to that point each render instead of clearing the whole console. This is only
        # possible on a real interactive host that exposes a settable CursorPosition.
        $rawUI = $Host.UI.RawUI
        $canRepaint = $false
        $startCursor = $null
        if (-not $ClearScreen) {
            try {
                $startCursor = $rawUI.CursorPosition
                $canRepaint = $null -ne $startCursor
            } catch {
                # Non-interactive / redirected host: fall back to plain append.
                $canRepaint = $false
            }
        }

        $firstPage = $true
        $lastPage = $false

        while ($true) {
            # Calculate the items for the current page
            $startIndex = ($currentPage - 1) * $MaxItemsPerPage
            $endIndex = [math]::Min($startIndex + $MaxItemsPerPage, $Items.Count) - 1
            $pagedItems = $Items[$startIndex..$endIndex]

            # Build the options array
            $array = [ordered]@{}
            $counter = 0

            # Add the Skip option if applicable
            if (-not $Required -and $AddSkip) {
                $array["0"] = $SkipText
            }

            # Add items for the current page
            foreach ($entry in $pagedItems) {
                $counter++
                $array["$counter"] = $entry
            }

            # Prepare the drawing surface for this render.
            if ($ClearScreen) {
                Clear-Host
            } elseif ($canRepaint) {
                # Rewind the cursor to where we first started drawing and wipe from
                # there down, so the menu repaints in place without touching the
                # console content that existed above $startCursor.
                try {
                    $rawUI.CursorPosition = $startCursor
                    $width = $rawUI.BufferSize.Width
                    $blankHeight = $rawUI.WindowSize.Height
                    $fill = [System.Management.Automation.Host.BufferCell]::new(
                        ' ', $rawUI.ForegroundColor, $rawUI.BackgroundColor, 'Complete')
                    $rect = [System.Management.Automation.Host.Rectangle]::new(
                        0, $startCursor.Y, $width - 1, $startCursor.Y + $blankHeight)
                    $rawUI.SetBufferContents($rect, $fill)
                    $rawUI.CursorPosition = $startCursor
                } catch {
                    # If anything about the buffer math fails, stop trying to repaint
                    # and just append from here on out.
                    $canRepaint = $false
                }
            }

            if ($TextBlock -and $TextBlockBefore) {
                Write-InformationColored "`n$TextBlock"
            }
            Write-InformationColored "`n$PromptText`n"
            if ($TextBlock -and -not $TextBlockBefore) {
                Write-InformationColored "$TextBlock`n"
            }
            Write-InformationColored "$('-' * $Host.UI.RawUI.WindowSize.Width)`n" -ForegroundColor DarkCyan
            foreach ($entry in $array.GetEnumerator()) {

                Write-InformationColored "$($entry.Name).`t" -ForegroundColor DarkCyan -NoNewline
                Write-InformationColored "$($entry.Value)"
            }
            Write-InformationColored "`n$('-' * $Host.UI.RawUI.WindowSize.Width)" -ForegroundColor DarkCyan
            # Show page info and navigation instructions if there are multiple pages
            if ($pages) {
                Write-InformationColored "`nPage $currentPage of $totalPages" -ForegroundColor Cyan
                if ($currentPage -eq 1) {
                    if ($NoNextPageOnEnter) {
                        Write-InformationColored "Press (n) for Next Page, (q) to Quit"
                    } else {
                        Write-InformationColored "Press (n) or (Enter) for Next Page, (q) to Quit"
                    }
                    $firstPage = $true
                    $lastPage = $false
                } elseif ($currentPage -eq $totalPages) {
                    Write-InformationColored "Press (p) for Previous Page, (q) to Quit"
                    $firstPage = $false
                    $lastPage = $true
                } else {
                    if ($NoNextPageOnEnter) {
                        Write-InformationColored "Press (n) for Next Page, (p) for Previous Page, (q) to Quit"
                    } else {
                        Write-InformationColored "Press (n) or (Enter) for Next Page, (p) for Previous Page, (q) to Quit"
                    }
                    $firstPage = $false
                    $lastPage = $false
                }
            }

            if ($errorText) {
                Write-InformationColored "`n$errorText" -ForegroundColor Red
                $errorText = ""
            }

            # Read user input
            if ($Required) {
                Write-InformationColored "`nRequired " -ForegroundColor Red -NoNewline
                $selection = Read-Host "Enter Option Number"
            } else {
                Write-InformationColored "`n(Optional) " -ForegroundColor White -NoNewline
                $selection = Read-Host "Enter Option Number or press [Enter] to skip"
            }

            # Handle selection
            if ([string]::IsNullOrEmpty($selection)) {
                if ($NoNextPageOnEnter) {
                    Write-Verbose "NoNextPageOnEnter is enabled. Ignoring Enter key for pagination."
                    if ($Required) {
                        $errorText = "Selection is required. Please try again."
                    } else {
                        return $null
                    }
                } elseif ($pages) {
                    Write-Verbose "No selection, NoNextPageOnEnter is not enabled, and multiple pages are available."
                    if ($Required -and $lastPage) {
                        $errorText = "You are already on the last page."
                    } elseif ($lastPage) {
                        return $null
                    } else {
                        $currentPage++
                    }
                } else {
                    Write-Verbose "No selection made. Exiting or skipping."
                    if ($Required) {
                        $errorText = "Selection is required. Please try again..."
                    } else {
                        return $null
                    }
                }
            } elseif ($selection -eq "q") {
                return $null
            } elseif ($selection -eq "n" -and $lastPage -eq $true) {
                $errorText = "You are already on the last page."
            } elseif ($selection -eq "p" -and $firstPage -eq $true) {
                $errorText = "You are already on the first page."
            } elseif ($selection -eq "n" -and $lastPage -eq $false) {
                $currentPage++
            } elseif ($selection -eq "p" -and $firstPage -eq $false) {
                $currentPage--
            } elseif ($array.Keys -contains "$selection") {
                return $array["$selection"]
            } else {
                $errorText = "Invalid selection '$selection'. Please try again."
            }
        }
    }
}

function Select-Item {
    <#
    .SYNOPSIS
        Ask the user to choose one item from an arbitrary object/collection.
    .DESCRIPTION
        Wraps Read-Choice so you can pass in any object or array of objects
        (PSCustomObject, hashtable entries, plain values, etc.) and get the
        ORIGINAL selected object back - not just its display label.

        Each entry is rendered using -DisplayProperty (if it exists on the item),
        otherwise its string representation is used. Duplicate display values are
        handled safely: identical labels get a trailing " (1)", " (2)", ... suffix so
        the user can tell them apart and each selection resolves to the exact object.
    .PARAMETER InputObject
        The object or collection of objects to choose from. Accepts pipeline input.
    .PARAMETER DisplayProperty
        Optional property name used to build each option's label.
    .PARAMETER PromptText
        Heading shown above the list.
    .PARAMETER Required
        Force a selection (no skip / $null result).
    .EXAMPLE
        $apps = Get-ChildItem C:\Apps
        $chosen = $apps | Select-Item -DisplayProperty Name -PromptText 'Pick an app'
        # $chosen is the original FileSystemInfo object
    .EXAMPLE
        'Red','Green','Blue' | Select-Item -PromptText 'Pick a color' -Required
    .OUTPUTS
        The originally supplied object that the user chose, or $null when skipped.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,

        [Parameter(Mandatory = $false)]
        [string]$DisplayProperty,

        [Parameter(Mandatory = $false)]
        [string]$PromptText = 'Select an option from the list below',

        [Parameter(Mandatory = $false)]
        [switch]$Required
    )
    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }
    process {
        foreach ($item in $InputObject) {
            $collected.Add($item)
        }
    }
    end {
        if ($collected.Count -eq 0) {
            Write-Error "InputObject is empty; nothing to select from."
            return
        }

        # Build display labels from each item. Read-Choice returns the chosen label
        # string, so labels must be UNIQUE for selection to resolve unambiguously.
        $rawLabels = foreach ($item in $collected) {
            if ($DisplayProperty -and $null -ne $item -and `
                ($item.PSObject.Properties.Name -contains $DisplayProperty)) {
                [string]$item.$DisplayProperty
            } else {
                [string]$item
            }
        }
        $rawLabels = @($rawLabels)

        # Disambiguate duplicate labels with a trailing " (n)" so the user can tell
        # them apart AND each label maps to exactly one object. Unique labels are left
        # untouched. We keep a label -> object map for exact resolution afterwards.
        $counts = @{}
        foreach ($l in $rawLabels) { $counts[$l] = ($counts[$l] + 1) }
        $seen = @{}
        $map = [ordered]@{}
        $labels = foreach ($i in 0..($collected.Count - 1)) {
            $base = $rawLabels[$i]
            if ($counts[$base] -gt 1) {
                $seen[$base] = ($seen[$base] + 1)
                $label = "$base ($($seen[$base]))"
            } else {
                $label = $base
            }
            $map[$label] = $collected[$i]
            $label
        }
        $labels = @($labels)

        $selection = Read-Choice -Items $labels -PromptText $PromptText -Required:$Required
        if ($null -eq $selection) {
            return $null
        }
        if ($map.Contains($selection)) {
            return $map[$selection]
        }
        return $null
    }
}

# Backwards-compatible aliases for the previous function names.
Set-Alias -Name Show-SelectList  -Value Read-Choice -Scope Global -Force
Set-Alias -Name Select-FromObject -Value Select-Item -Scope Global -Force

# --- Quick manual test (uncomment to try) -------------------------------------
# $people = @(
#     [pscustomobject]@{ Name = 'Alice'; Role = 'Admin' }
#     [pscustomobject]@{ Name = 'Bob';   Role = 'User'  }
# )
# $picked = $people | Select-Item -DisplayProperty Name -PromptText 'Choose a person' -Required
# "You picked: $($picked.Name) ($($picked.Role))"
