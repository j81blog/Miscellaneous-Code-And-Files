#
# Module manifest for module 'JB.CitrixWEM'
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'JB.CitrixWEM.psm1'

    # Version number of this module.
    ModuleVersion     = '2025.805.2230'

    # Supported PSEditions
    # CompatiblePSEditions = @()

    # ID used to uniquely identify this module
    GUID              = '67fd0866-1f76-4601-bbd0-252af6985e19'

    # Author of this module
    Author            = 'John Billekens Consultancy'

    # Company or vendor of this module
    CompanyName       = 'John Billekens Consultancy'

    # Copyright statement for this module
    Copyright         = '(c) 2025 John Billekens Consultancy. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'JB.CitrixWEM is a PowerShell module designed to interact with Citrix Workspace Environment Management (WEM) APIs, providing functions to manage WEM Configuration Sets, printers, and other resources.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Name of the Windows PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    # ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'New-WEMPrinter',
        'New-WEMPrinterAssignment',
        'Get-WEMPrinter',
        'Get-WEMPrinterAssignment',
        'Remove-WEMPrinter',
        'Get-WEMAssignmentTarget',
        'New-WEMAssignmentTarget',
        'Remove-WEMAssignmentTarget',
        'Get-WEMActionSettings',
        'Get-WEMConfigurationSite',
        'Search-WEMActiveDirectoryObject',
        'Get-WEMADForest',
        'Get-WEMADDomain',
        'Connect-WEMApi'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport   = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport   = '*'

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    # FileList = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags       = 'JB.CitrixWEM', 'Citrix', 'WEM', 'Workspace Environment Management', 'PowerShell', 'API'

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/j81blog/JB.CitrixWEM/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/j81blog/JB.CitrixWEM'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            # ReleaseNotes = ''

        } # End of PSData hashtable

    } # End of PrivateData hashtable

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''

}
