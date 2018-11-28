@{
    # Version number of this module.
    moduleVersion = '4.2.0.0'

    # ID used to uniquely identify this module
    GUID = '3bcb9c66-ea0b-4675-bd46-c390a382c388'

    # Author of this module
    Author = 'Microsoft Corporation'

    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright = '(c) 2018 Microsoft Corporation. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'DSC resources for configuring Distributed File System Replication and Namespaces.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion = '4.0'

    # Processor architecture (None, X86, Amd64) required by this module
    ProcessorArchitecture = 'None'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module
    FunctionsToExport = '*'

    # Cmdlets to export from this module
    CmdletsToExport = '*'

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @( 'DSC','DesiredStateConfiguration','DSCResourceKit','DSCResource','DFS','DistributedFileSystem' )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/PowerShell/DFSDsc/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/PowerShell/DFSDsc'

            # ReleaseNotes of this module
        ReleaseNotes = '- Add support for modifying staging quota size in
  MSFT_DFSReplicationGroupMembership - fixes [Issue 77](https://github.com/PowerShell/DfsDsc/issues/77).
- Refactored module folder structure to move resource to root folder of
  repository and remove test harness - fixes [Issue 74](https://github.com/PowerShell/DfsDsc/issues/74).
- Updated Examples to support deployment to PowerShell Gallery scripts.
- Remove exclusion of all tags in appveyor.yml, so all common tests can be run
  if opt-in.
- Added .VSCode settings for applying DSC PSSA rules - fixes [Issue 75](https://github.com/PowerShell/DfsDsc/issues/75).
- Updated LICENSE file to match the Microsoft Open Source Team
  standard - fixes [Issue 79](https://github.com/PowerShell/DFSDsc/issues/79)

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}




