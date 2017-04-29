# xDFS

[![Build status](https://ci.appveyor.com/api/projects/status/5hkcpe757hhe4583?svg=true)](https://ci.appveyor.com/project/PowerShell/xdfs)
[![codecov](https://codecov.io/gh/PowerShell/xDFS/branch/master/graph/badge.svg)](https://codecov.io/gh/PowerShell/xDFS)

The **xDFS** module contains DSC resources for configuring Distributed File
System Replication and Namespaces. Currently in this version only Replication
folders are supported. Namespaces will be supported in a future release.

The **xDFS** module contains the following resources:

- **xDFSNamespaceFolder**: Create, edit or remove folders from DFS namespaces.
- **xDFSNamespaceRoot**: Create, edit or remove standalone or domain based DFS
  namespaces.
- **xDFSNamespaceServerConfiguration**: Configure DFS Namespace server settings.
- **xDFSReplicationGroup**: Create, edit or remove DFS Replication Groups.
- **xDFSReplicationGroupConnection**: Create, edit and remove DFS Replication
  Group connections.
- **xDFSReplicationGroupFolder**: Configure DFS Replication Group folders.
- **xDFSReplicationGroupMembership**: Configure Replication Group Folder
  Membership.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Requirements

- **Windows Management Framework 5.0**: Required because the
  PSDSCRunAsCredential DSC Resource parameter is needed.

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

### Domain Credentials

Because this resource is configuring information within Active Directory, the
**PSDSCRunAsCredential** property must be used with a credential of a domain
user that can work with DFS information. This means that this resource can only
work on computers with Windows Management Framework 5.0 or above.

## Contributing

Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).
