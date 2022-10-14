# DFSDsc

[![Build Status](https://dev.azure.com/dsccommunity/DFSDsc/_apis/build/status/dsccommunity.DFSDsc?branchName=main)](https://dev.azure.com/dsccommunity/DFSDsc/_build/latest?definitionId=35&branchName=main)
![Code Coverage](https://img.shields.io/azure-devops/coverage/dsccommunity/DFSDsc/35/main)
[![Azure DevOps tests](https://img.shields.io/azure-devops/tests/dsccommunity/DFSDsc/35/main)](https://dsccommunity.visualstudio.com/DFSDsc/_test/analytics?definitionId=35&contextType=build)
[![PowerShell Gallery (with prereleases)](https://img.shields.io/powershellgallery/vpre/DFSDsc?label=DFSDsc%20Preview)](https://www.powershellgallery.com/packages/DFSDsc/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/DFSDsc?label=DFSDsc)](https://www.powershellgallery.com/packages/DFSDsc/)
[![codecov](https://codecov.io/gh/dsccommunity/DFSDsc/branch/main/graph/badge.svg)](https://codecov.io/gh/dsccommunity/DFSDsc)

## Code of Conduct

This project has adopted [this code of conduct](CODE_OF_CONDUCT.md).

## Releases

For each merge to the branch `main` a preview release will be
deployed to [PowerShell Gallery](https://www.powershellgallery.com/).
Periodically a release version tag will be pushed which will deploy a
full release to [PowerShell Gallery](https://www.powershellgallery.com/).

## Contributing

Please check out common DSC Community [contributing guidelines](https://dsccommunity.org/guidelines/contributing).

## Change log

A full list of changes in each version can be found in the [change log](CHANGELOG.md).

## Resources

The **DFSDsc** module contains DSC resources for configuring Distributed File
System Replication and Namespaces. Currently in this version only Replication
folders are supported. Namespaces will be supported in a future release.

The **DFSDsc** module contains the following resources:

- **[DFSNamespaceFolder](https://github.com/PowerShell/DFSDsc/wiki/DFSNamespaceFolder)**:
  Create, edit or remove folders from DFS namespaces.
- **[DFSNamespaceRoot](https://github.com/PowerShell/DFSDsc/wiki/DFSNamespaceRoot)**:
  Create, edit or remove standalone or domain based DFS namespaces.
- **[DFSNamespaceServerConfiguration](https://github.com/PowerShell/DFSDsc/wiki/DFSNamespaceServerConfiguration)**:
  Configure DFS Namespace server settings.
- **[DFSReplicationGroup](https://github.com/PowerShell/DFSDsc/wiki/DFSReplicationGroup)**:
  Create, edit or remove DFS Replication Groups.
- **[DFSReplicationGroupConnection](https://github.com/PowerShell/DFSDsc/wiki/DFSReplicationGroupConnection)**:
  Create, edit and remove DFS Replication Group connections.
- **[DFSReplicationGroupFolder](https://github.com/PowerShell/DFSDsc/wiki/DFSReplicationGroupFolder)**:
  Configure DFS Replication Group folders.
- **[DFSReplicationGroupMember](https://github.com/PowerShell/DFSDsc/wiki/DFSReplicationGroupMember)**:
  Configure Replication Group Folder Members.
- **[DFSReplicationGroupMembership](https://github.com/PowerShell/DFSDsc/wiki/DFSReplicationGroupMembership)**:
  Configure Replication Group Folder Membership.

## Documentation and Examples

For a full list of resources in DFSDsc and examples on their use, check out
the [DFSDsc wiki](https://github.com/PowerShell/DFSDsc/wiki).

## Requirements

### Windows Management Framework 5.0

Required because the PSDSCRunAsCredential DSC Resource parameter is needed.

Because this resource is configuring information within Active Directory, the
**PSDSCRunAsCredential** property must be used with a credential of a domain
user that can work with DFS information.
This means that this resource can only work on computers with Windows
Management Framework 5.0 or above.

## Important Information

### DFSR Module

This DSC Resource requires that the DFSR PowerShell module is installed onto
any computer this resource will be used on. This module is installed as part of
RSAT tools or RSAT-DFS-Mgmt-Con Windows Feature in Windows Server 2012 R2.
However, this will automatically convert a Server Core installation into one
containing the management tools, which may not be ideal because it is no longer
strictly a Server Core installation.
Because this DSC Resource actually only configures information within the AD,
it is only required that this resource is run on a computer that is registered
in AD. It doesn't need to be run on one of the File Servers participating
in the Distributed File System or Namespace.
