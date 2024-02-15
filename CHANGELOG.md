# Change log for DFSDsc

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- DFSNamespaceRoot
  - Added support for setting the state of the namespace root (State)
- DFSNamespaceFolder
  - Added support for setting the state of the namespace folder (State)
- DFSNamespaceServerConfiguration
  - Added support for setting EnableSiteCostedReferrals, EnableInsiteReferrals and PreferLogonDC on a DFS namespace server
 
### Fixed

- Updated out of date README.MD.

## [5.0.1] - 2023-09-07

### Fixed

- DFSDsc
  - Removed the pipeline files `build.psd1` as it is no longer needed.

## [5.0.0] - 2023-09-01

### Changed

- DFSNamespaceRoot
  - Added support for setting target referral status (TargetState) - fixes [Issue #96](https://github.com/dsccommunity/DFSDsc/issues/96).
  - Converted 'Ensure' parameters to default to 'Present' - fixes [Issue #29](https://github.com/dsccommunity/DFSDsc/issues/29).
- DFSNamespaceFolder
  - Added support for setting target referral status (TargetState) - fixes [Issue #96](https://github.com/dsccommunity/DFSDsc/issues/96).
  - Converted 'Ensure' parameters to default to 'Present' - fixes [Issue #29](https://github.com/dsccommunity/DFSDsc/issues/29).
- DFSReplicationGroup
  - Converted 'Ensure' parameters to default to 'Present' - fixes [Issue #29](https://github.com/dsccommunity/DFSDsc/issues/29).
- DFSReplicationGroupMember
  - New module allowing replication group members to be separately defined outside of DFSReplicationGroup.
    This allows situations where new memberships may be added separately on individual servers, instead of a single server.
- DFSReplicationGroupConnection
  - Add support for setting CrossFileRDCEnabled and MinimumRDCFileSizeInKB.
  - Converted 'Ensure' parameters to default to 'Present' - fixes [Issue #29](https://github.com/dsccommunity/DFSDsc/issues/29).
- DFSReplicationGroupFolder
  - Allow Get-TargetResource and Test-TargetResource to run if group does not exist - fixes [Issue #125](https://github.com/dsccommunity/DFSDsc/issues/125).
- DFSReplicationGroupMembership
  - Add support for setting EnsureEnabled, MinimumFileStagingSize, ConflictAndDeletedQuotaInMB, RemoveDeletedFiles and DfsnPath.
  - Allow Get-TargetResource and Test-TargetResource to run if group does not exist - fixes [Issue #125](https://github.com/dsccommunity/DFSDsc/issues/125).
- BREAKING CHANGE: Changed resource prefix from MSFT to DSC.
- Updated to use continuous delivery pattern using Azure DevOps - fixes
  [Issue #41](https://github.com/dsccommunity/DFSDsc/issues/98).
- Updated build badges in README.MD.
- Renamed `DFSDsc.ResourceHelper` module to `DFSDsc.Common` to align to
  other modules.
- Correct case of localization folder names.
- Update build badges in `README.md` with correct build IDs.
- DFSDsc
  - Updated to use the common module _DscResource.Common_ - Fixes [Issue #102](https://github.com/dsccommunity/DFSDsc/issues/102).
  - Fixed build failures caused by changes in `ModuleBuilder` module v1.7.0
    by changing `CopyDirectories` to `CopyPaths` - Fixes [Issue #103](https://github.com/dsccommunity/DFSDsc/issues/103).
  - Pin `Pester` module to 4.10.1 because Pester 5.0 is missing code
    coverage - Fixes [Issue #105](https://github.com/dsccommunity/DFSDsc/issues/105).
- Renamed `master` branch to `main` - Fixes [Issue #108](https://github.com/dsccommunity/DFSDsc/issues/108).
- Corrected build badge URLs in README.md.
- Minor corrections to pipeline files and examples after renaming `master`
  branch to `main`.
- DFSDsc
  - Automatically publish documentation to GitHub Wiki - Fixes [Issue #109](https://github.com/dsccommunity/DFSDsc/issues/109).
- Updated `GitVersion.yml` to latest pattern - Fixes [Issue #113](https://github.com/dsccommunity/DFSDsc/issues/113).
- Updated build to use `Sampler.GitHubTasks` - Fixes [Issue #116](https://github.com/dsccommunity/DFSDsc/issues/116).
- Added support for publishing code coverage to `CodeCov.io` and
  Azure Pipelines - Fixes [Issue #115](https://github.com/dsccommunity/DFSDsc/issues/115).
- Removed duplicate code coverage badge.
- Updated .github issue templates to standard - Fixes [Issue #123](https://github.com/dsccommunity/DFSDsc/issues/123).
- Added Create_ChangeLog_GitHub_PR task to publish stage of build pipeline.
- Added SECURITY.md.
- Updated pipeline Deploy_Module anb Code_Coverage jobs to use ubuntu-latest
  images - Fixes [Issue #122](https://github.com/dsccommunity/DFSDsc/issues/122).
- Updated pipeline unit tests and integration tests to use Windows Server 2019 and
  Windows Server 2022 images - Fixes [Issue #122](https://github.com/dsccommunity/DFSDsc/issues/122).
- Temporarily pinned build image to Ubuntu 20.04 - Fixes [Issue #127](https://github.com/dsccommunity/DFSDsc/issues/127).

### Fixed

- Fixed pipeline by replacing the GitVersion task in the `azure-pipelines.yml`
  with a script.

## [4.4.0.0] - 2019-09-19

### Changed

- Fix example publish to PowerShell Gallery by adding `gallery_api`
  environment variable to `AppVeyor.yml` - fixes [Issue #91](https://github.com/PowerShell/DfsDsc/issues/91).
- Fix minor style issues in statement case.

## [4.3.0.0] - 2019-02-20

### Changed

- Fixes PSSA style violation issues resulting - fixes [Issue #84](https://github.com/PowerShell/DfsDsc/issues/84).
- Added 'DscResourcesToExport' to manifest to improve information in
  PowerShell Gallery - fixes [Issue #86](https://github.com/PowerShell/DfsDsc/issues/86).
- Set FunctionsToExport, CmdletsToExport, VariablesToExport, AliasesToExport
  to empty list in manifest to meet best practice.
- Explicitly removed extra hidden files from release package

## [4.2.0.0] - 2018-11-29

### Changed

- Add support for modifying staging quota size in
  MSFT_DFSReplicationGroupMembership - fixes [Issue #77](https://github.com/PowerShell/DfsDsc/issues/77).
- Refactored module folder structure to move resource to root folder of
  repository and remove test harness - fixes [Issue #74](https://github.com/PowerShell/DfsDsc/issues/74).
- Updated Examples to support deployment to PowerShell Gallery scripts.
- Remove exclusion of all tags in appveyor.yml, so all common tests can be run
  if opt-in.
- Added .VSCode settings for applying DSC PSSA rules - fixes [Issue #75](https://github.com/PowerShell/DfsDsc/issues/75).
- Updated LICENSE file to match the Microsoft Open Source Team
  standard - fixes [Issue #79](https://github.com/PowerShell/DFSDsc/issues/79)

## [4.1.0.0] - 2018-06-13

### Changed

- Added Hub and Spoke replication group example - fixes [Issue #62](https://github.com/PowerShell/DFSDsc/issues/62).
- Enabled PSSA rule violations to fail build - fixes [Issue #320](https://github.com/PowerShell/DFSDsc/issues/59).
- Allow null values in resource group members or folders - fixes [Issue #27](https://github.com/PowerShell/xDFS/issues/27).
- Added a CODE\_OF\_CONDUCT.md with the same content as in the README.md - fixes
  [Issue #67](https://github.com/PowerShell/DFSDsc/issues/67).

## [4.0.0.0] - 2018-05-03

### Changed

- BREAKING CHANGE
  - Renamed xDFS to DFSDsc - fixes [Issue #55](https://github.com/PowerShell/xDFS/issues/55).
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
- Opted into Common Tests 'Validate Module Files' and 'Validate Script Files'.
- Converted files with UTF8 with BOM over to UTF8 - fixes [Issue #47](https://github.com/PowerShell/xDFS/issues/47).
- Added `Documentation and Examples` section to Readme.md file - see
  [issue #49](https://github.com/PowerShell/xDFS/issues/49).
- Prevent unit tests from DSCResource.Tests from running during test
  execution - fixes [Issue #51](https://github.com/PowerShell/xDFS/issues/51).
- Updated tests to meet Pester V4 guidelines - fixes [Issue #53](https://github.com/PowerShell/xDFS/issues/53).

## [3.2.0.0] - 2017-06-01

### Changed

- Converted AppVeyor.yml to pull Pester from PSGallery instead of Chocolatey.
- Changed AppVeyor.yml to use default image.
- Converted AppVeyor build process to use AppVeyor.psm1.
- Resolved PSSA violations.
- Resolved Readme.md style violations.
- Converted Integration Tests to use Test Drive and stop using Invoke-Pester.
- Move strings into separate language files.
- Added CodeCov support.
- Clean up manifest file by removing commented out sections.
- Convert Examples to pass tests and meet minimum standards.
- Convert to Wiki and auto-documentation generation.
- Convert to TestHarness test execution method.
- Correct parameter block format to meet guidelines.
- Replaced all type accelerators with full type names.
- Updated Readme.md to contain resource list.
- Fixed xDFSNamespaceServerConfiguration by converting LocalHost to ComputerName
  instead.
- Added integration test to test for conflicts with other common resource kit modules.
- Prevented ResourceHelper and Common module cmdlets from being exported to resolve
  conflicts with other resource modules.

## [3.1.0.0] - 2016-06-29

### Changed

- MSFT_xDFSNamespaceServerConfiguration- resource added.
- Corrected names of DFS Namespace sample files to indicate that they are setting
  Namespace roots and folders.
- Removed Pester version from AppVeyor.yml.

## [3.0.0.0] - 2016-05-11

### Changed

- RepGroup renamed to ReplicationGroup in all files.
- xDFSReplicationGroupConnection- Changed DisableConnection parameter to EnsureEnabled.
                                  Changed DisableRDC parameter to EnsureRDCEnabled.
- xDFSReplicationGroup- Fixed bug where disabled connection was not enabled in
  Fullmesh topology.

## [2.2.0.0] - 2016-01-01

### Changed

- DSC Module moved to MSFT.
- MSFT_xDFSNamespace- Removed.

## [2.1.0.0] - 2016-01-01

### Changed

- MSFT_xDFSRepGroup- Fixed issue when using FQDN member names.
- MSFT_xDFSRepGroupMembership- Fixed issue with Get-TargetResource when using
  FQDN ComputerName.
- MSFT_xDFSRepGroupConnection- Fixed issue with Get-TargetResource when using
  FQDN SourceComputerName or FQDN DestinationComputerName.
- MSFT_xDFSNamespaceRoot- Added write support to TimeToLiveSec parameter.
- MSFT_xDFSNamespaceFolder- Added write support to TimeToLiveSec parameter.

## [2.0.0.0] - 2016-01-01

### Changed

- MSFT_xDFSNamespaceRoot- resource added.
- MSFT_xDFSNamespaceFolder- resource added.
- MSFT_xDFSNamespace- deprecated - use MSFT_xDFSNamespaceRoot instead.

## [1.5.1.0] - 2016-01-01

### Changed

- MSFT_xDFSNamespace- Add parameters:
  - EnableSiteCosting
  - EnableInsiteReferrals
  - EnableAccessBasedEnumeration
  - EnableRootScalability
  - EnableTargetFailback
  - ReferralPriorityClass
  - ReferralPriorityRank

## [1.5.0.0] - 2016-01-01

### Changed

- MSFT_xDFSNamespace- New sample files added.
- MSFT_xDFSNamespace- MOF parameter descriptions corrected.
- MSFT_xDFSNamespace- Rearchitected code.
- MSFT_xDFSNamespace- SMB Share is no longer removed when a namespace or target
  is removed.
- MSFT_xDFSNamespace- Removed SMB Share existence check.
- Documentation layout corrected.
- MSFT_xDFSRepGroup- Array Parameter output disabled in Get-TargetResource
  until [this issue](https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type)
  is resolved.

## [1.4.2.0] - 2016-01-01

### Changed

- MSFT_xDFSRepGroup- Fixed "Cannot bind argument to parameter 'DifferenceObject'
  because it is null." error.
- All Unit tests updated to use *_TestEnvironment functions in DSCResource.Tests\TestHelpers.psm1

## [1.4.1.0] - 2016-01-01

### Changed

- MSFT_xDFSNamespace- Renamed Sample_DcFSNamespace.ps1 to Sample_xDFSNamespace.
- MSFT_xDFSNamespace- Corrected Import-DscResouce in example.

## [1.4.0.0] - 2016-01-01

### Changed

- Community update by Erik Granneman
- New DSC recource xDFSNameSpace

## [1.3.2.0] - 2016-01-01

### Changed

- Documentation and Module Manifest Update only.

## [1.3.1.0] - 2016-01-01

### Changed

- xDFSRepGroupFolder- DfsnPath parameter added for setting DFS Namespace path mapping.

## [1.3.0.0] - 2016-01-01

### Changed

- xDFSRepGroup- If ContentPaths is set, PrimaryMember is set to first member in
  the Members array.
- xDFSRRepGroupMembership- PrimaryMembers property added so that Primary Member
  can be set.

## [1.2.1.0] - 2016-01-01

### Changed

- xDFSRepGroup- Fix to ContentPaths generation when more than one folder is provided.

## [1.2.0.0] - 2016-01-01

### Changed

- xDFSRepGroup- ContentPaths string array parameter.

## [1.1.0.0] - 2016-01-01

### Changed

- xDFSRepGroupConnection- Resource added.

## [1.0.0.0] - 2016-01-01

### Changed

- Initial release.
