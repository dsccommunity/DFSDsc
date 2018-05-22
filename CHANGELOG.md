# Versions

## Unreleased

- Added Hub and Spoke replication group example - fixes [Issue #62](https://github.com/PowerShell/DFSDsc/issues/62).
- Enabled PSSA rule violations to fail build - Fixes [Issue #320](https://github.com/PowerShell/DFSDsc/issues/59).

## 4.0.0.0

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

## 3.2.0.0

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

## 3.1.0.0

- MSFT_xDFSNamespaceServerConfiguration- resource added.
- Corrected names of DFS Namespace sample files to indicate that they are setting
  Namespace roots and folders.
- Removed Pester version from AppVeyor.yml.

## 3.0.0.0

- RepGroup renamed to ReplicationGroup in all files.
- xDFSReplicationGroupConnection- Changed DisableConnection parameter to EnsureEnabled.
                                  Changed DisableRDC parameter to EnsureRDCEnabled.
- xDFSReplicationGroup- Fixed bug where disabled connection was not enabled in
  Fullmesh topology.

## 2.2.0.0

- DSC Module moved to MSFT.
- MSFT_xDFSNamespace- Removed.

## 2.1.0.0

- MSFT_xDFSRepGroup- Fixed issue when using FQDN member names.
- MSFT_xDFSRepGroupMembership- Fixed issue with Get-TargetResource when using
  FQDN ComputerName.
- MSFT_xDFSRepGroupConnection- Fixed issue with Get-TargetResource when using
  FQDN SourceComputerName or FQDN DestinationComputerName.
- MSFT_xDFSNamespaceRoot- Added write support to TimeToLiveSec parameter.
- MSFT_xDFSNamespaceFolder- Added write support to TimeToLiveSec parameter.

## 2.0.0.0

- MSFT_xDFSNamespaceRoot- resource added.
- MSFT_xDFSNamespaceFolder- resource added.
- MSFT_xDFSNamespace- deprecated - use MSFT_xDFSNamespaceRoot instead.

## 1.5.1.0

- MSFT_xDFSNamespace- Add parameters:
  - EnableSiteCosting
  - EnableInsiteReferrals
  - EnableAccessBasedEnumeration
  - EnableRootScalability
  - EnableTargetFailback
  - ReferralPriorityClass
  - ReferralPriorityRank

## 1.5.0.0

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

## 1.4.2.0

- MSFT_xDFSRepGroup- Fixed "Cannot bind argument to parameter 'DifferenceObject'
  because it is null." error.
- All Unit tests updated to use *_TestEnvironment functions in DSCResource.Tests\TestHelpers.psm1

## 1.4.1.0

- MSFT_xDFSNamespace- Renamed Sample_DcFSNamespace.ps1 to Sample_xDFSNamespace.
- MSFT_xDFSNamespace- Corrected Import-DscResouce in example.

## 1.4.0.0

- Community update by Erik Granneman
- New DSC recource xDFSNameSpace

## 1.3.2.0

- Documentation and Module Manifest Update only.

## 1.3.1.0

- xDFSRepGroupFolder- DfsnPath parameter added for setting DFS Namespace path mapping.

## 1.3.0.0

- xDFSRepGroup- If ContentPaths is set, PrimaryMember is set to first member in
  the Members array.
- xDFSRRepGroupMembership- PrimaryMembers property added so that Primary Member
  can be set.

## 1.2.1.0

- xDFSRepGroup- Fix to ContentPaths generation when more than one folder is provided.

## 1.2.0.0

- xDFSRepGroup- ContentPaths string array parameter.

## 1.1.0.0

- xDFSRepGroupConnection- Resource added.

## 1.0.0.0

- Initial release.
