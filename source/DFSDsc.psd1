@{
    # Version number of this module.
    ModuleVersion         = '0.0.1'

    # ID used to uniquely identify this module
    GUID                  = '3bcb9c66-ea0b-4675-bd46-c390a382c388'

    # Author of this module
    Author               = 'DSC Community'

    # Company or vendor of this module
    CompanyName          = 'DSC Community'

    # Copyright statement for this module
    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    # Description of the functionality provided by this module
    Description           = 'DSC resources for configuring Distributed File System Replication and Namespaces.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion     = '5.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion            = '4.0'

    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport     = @()

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport       = @()

    # Variables to export from this module
    VariablesToExport     = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport       = @()

    # DSC resources to export from this module
    DscResourcesToExport  = @(
        'DFSNamespaceFolder',
        'DFSNamespaceRoot',
        'DFSNamespaceServerConfiguration',
        'DFSReplicationGroup',
        'DFSReplicationGroupConnection',
        'DFSReplicationGroupFolder',
        'DFSReplicationGroupMember',
        'DFSReplicationGroupMembership'
    )

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData           = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @( 'DSC', 'DesiredStateConfiguration', 'DSCResource', 'DFS', 'DistributedFileSystem', 'Replication', 'Namespace' )

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/DFSDsc/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/DFSDsc'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}
