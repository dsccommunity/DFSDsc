@{
    # Version number of this module.
    moduleVersion = '4.0.0.0'

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
        ReleaseNotes = '- BREAKING CHANGE
  - Renamed xDFS to DFSDsc - fixes [Issue 55](https://github.com/PowerShell/xDFS/issues/55).
  - Changed all MSFT_xResourceName to MSFT_DFSResourceName.
  - Updated DSCResources, Examples, Modules and Tests for new naming.
  - Updated Year to 2018 in License and Manifest.
  - Changed all Modules\DFSDsc\Examples\Resources to DFSResourceName.
- Added the VS Code PowerShell extension formatting settings that cause PowerShell
  files to be formatted as per the DSC Resource kit style guidelines.
- Improve layout of badge area in README.MD.
- Disabled MD013 rule checking to enable badge table.
- Updated Year to 2017 in License and Manifest.
- Added .github support files:
  - CONTRIBUTING.md
  - ISSUE_TEMPLATE.md
  - PULL_REQUEST_TEMPLATE.md
- Opted into Common Tests "Validate Module Files" and "Validate Script Files".
- Converted files with UTF8 with BOM over to UTF8 - fixes [Issue 47](https://github.com/PowerShell/xDFS/issues/47).
- Added `Documentation and Examples` section to Readme.md file - see
  [issue 49](https://github.com/PowerShell/xDFS/issues/49).
- Prevent unit tests from DSCResource.Tests from running during test
  execution - fixes [Issue 51](https://github.com/PowerShell/xDFS/issues/51).
- Updated tests to meet Pester V4 guidelines - fixes [Issue 53](https://github.com/PowerShell/xDFS/issues/53).

'
        } # End of PSData hashtable
    } # End of PrivateData hashtable
}


