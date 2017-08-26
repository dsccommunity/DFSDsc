# xDFS

The **xDFS** module contains DSC resources for configuring Distributed File
System Replication and Namespaces. Currently in this version only Replication
folders are supported. Namespaces will be supported in a future release.

The **xDFS** module contains the following resources:

- **[xDFSNamespaceFolder](https://github.com/PowerShell/xDFS/wiki/xDFSNamespaceFolder)**:
  Create, edit or remove folders from DFS namespaces.
- **[xDFSNamespaceRoot](https://github.com/PowerShell/xDFS/wiki/xDFSNamespaceRoot)**:
  Create, edit or remove standalone or domain based DFS namespaces.
- **[xDFSNamespaceServerConfiguration](https://github.com/PowerShell/xDFS/wiki/xDFSNamespaceServerConfiguration)**:
  Configure DFS Namespace server settings.
- **[xDFSReplicationGroup](https://github.com/PowerShell/xDFS/wiki/xDFSReplicationGroup)**:
  Create, edit or remove DFS Replication Groups.
- **[xDFSReplicationGroupConnection](https://github.com/PowerShell/xDFS/wiki/xDFSReplicationGroupConnection)**:
  Create, edit and remove DFS Replication Group connections.
- **[xDFSReplicationGroupFolder](https://github.com/PowerShell/xDFS/wiki/xDFSReplicationGroupFolder)**:
  Configure DFS Replication Group folders.
- **[xDFSReplicationGroupMembership](https://github.com/PowerShell/xDFS/wiki/xDFSReplicationGroupMembership)**:
  Configure Replication Group Folder Membership.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Documentation and Examples

For a full list of resources in xDFS and examples on their use, check out
the [xDFS wiki](https://github.com/PowerShell/xDFS/wiki).

You can also review the `examples` directory in the xDFS module for some
general use scenarios for all of the resources that are in the module. If
you have installed this module from the PowerShell Gallery, the `en-US`
directory in the contains locally available copies of the resource documentation.

## Branches

### master

[![Build status](https://ci.appveyor.com/api/projects/status/5hkcpe757hhe4583/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xDFS/branch/master)
[![codecov](https://codecov.io/gh/PowerShell/xDFS/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/xDFS/branch/master)

This is the branch containing the latest release - no contributions should be made
directly to this branch.

### dev

[![Build status](https://ci.appveyor.com/api/projects/status/5hkcpe757hhe4583/branch/dev?svg=true)](https://ci.appveyor.com/project/PowerShell/xDFS/branch/dev)
[![codecov](https://codecov.io/gh/PowerShell/xDFS/branch/dev/graph/badge.svg)](https://codecov.io/gh/PowerShell/xDFS/branch/dev)

This is the development branch to which contributions should be proposed by contributors
as pull requests. This development branch will periodically be merged to the master
branch, and be released to [PowerShell Gallery](https://www.powershellgallery.com/).

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

## Contributing

Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).
