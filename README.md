[![Build status](https://ci.appveyor.com/api/projects/status/5hkcpe757hhe4583?svg=true)](https://ci.appveyor.com/project/PowerShell/xdfs)

# xDFS

The **xDFS** module contains DSC resources for configuring Distributed File System Replication and Namespaces. Currently in this version only Replication folders are supported. Namespaces will be supported in a future release.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Requirements
* **Windows Management Framework 5.0**: Required because the PSDSCRunAsCredential DSC Resource parameter is needed.

## Installation
```powershell
Install-Module -Name xDFS -MinimumVersion 3.0.0.0
```

## Important Information
### DFSR Module
This DSC Resource requires that the DFSR PowerShell module is installed onto any computer this resource will be used on. This module is installed as part of RSAT tools or RSAT-DFS-Mgmt-Con Windows Feature in Windows Server 2012 R2.
However, this will automatically convert a Server Core installation into one containing the management tools, which may not be ideal because it is no longer strictly a Server Core installation.
Because this DSC Resource actually only configures information within the AD, it is only required that this resource is run on a computer that is registered in AD. It doesn't need to be run on one of the File Servers participating
in the Distributed File System or Namespace.

### Domain Credentials
Because this resource is configuring information within Active Directory, the **PSDSCRunAsCredential** property must be used with a credential of a domain user that can work with DFS information. This means that this resource can only work on computers with Windows Management Framework 5.0 or above.


## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Replication Group Resources
### xDFSReplicationGroup
This resource is used to create, edit or remove DFS Replication Groups. If used to create a Replication Group it should be combined with the xDFSReplicationGroupMembership resources.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group is either Absent or Present. Required. { Absent | Present }
* **Description**: A description for the Replication Group. Optional.
* **Members**: A list of computers that are members of this Replication Group. These can be specified using either the ComputerName or FQDN name for each member. If an FQDN name is used and the DomainName parameter is set, the FQDN domain name must match. Optional.
* **Folders**: A list of folders that are replicated in this Replication Group. Optional.
* **Topology**: This allows a replication topology to assign to the Replication Group. It defaults to Manual, which will not automatically create a topology. If set to Fullmesh, a full mesh topology between all members will be created. Optional.
* **ContentPaths**: An array of DFS Replication Group Content Paths to use for each of the Folders. This can have one entry for each Folder in the Folders parameter and should be set in th same order. If any entry is not blank then the Content Paths will need to be set manually by using the xDFSReplicationGroupMembership resource. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### xDFSReplicationGroupConnection
This resource is used to create, edit and remove DFS Replication Group connections. This resource should ONLY be used if the Topology parameter in the Resource Group is set to Manual.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group connection is either Absent or Present. Required. { Absent | Present }
* **SourceComputerName**: The name of the Replication Group source computer for the connection. This can be specified using either the ComputerName or FQDN name for the member. If an FQDN name is used and the DomainName parameter is set, the FQDN domain name must match. Required.
* **DestinationComputerName**: The name of the Replication Group destination computer for the connection. This can be specified using either the ComputerName or FQDN name for the member. If an FQDN name is used and the DomainName parameter is set, the FQDN domain name must match. Required.
* **Description**: A description for the Replication Group connection. Optional.
* **EnsureEnabled**: Ensures that connection is either Enabled or Disabled. Optional. { Enabled | Disabled }. Default: Enabled.
* **EnsureRDCEnabled**: Ensures remote differential compression is Enabled or Disabled. Optional.  { Enabled | Disabled }. Default: Enabled.
* **DomainName**: The AD domain the Replication Group connection should created in. Optional.

### xDFSReplicationGroupFolder
This resource is used to configure DFS Replication Group folders. This is an optional resource, and only needs to be used if the folder Description, FilenameToExclude or DirectoryNameToExclude fields need to be set. In most cases just setting the Folders property in the xDFSReplicationGroup resource will be acceptable.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The name of the Replication Group folder. Required.
* **Description**: A description for the Replication Group. Optional.
* **FilenameToExclude**: An array of file names to exclude from replication. Optional.
* **DirectoryNameToExclude**: An array of directory names to exclude from replication. Optional.
* **DfsnPath**: The DFS Namespace Path to this Replication Group folder is mapped to. This does NOT create the Namespace folders, it only sets the name in the folder object. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### xDFSReplicationGroupMembership
This resource is used to configure Replication Group Folder Membership. It is usually used to set the **ContentPath** for each Replication Group folder on each Member computer. It can also be used to set additional properties of the Membership. This resource shouldn't be used for folders where the Content Path is set in the xDFSReplicationGroup.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The folder name of the Replication Group folder. Required.
* **ComputerName**: The computer name of the Replication Group member. This can be specified using either the ComputerName or FQDN name for the member. If an FQDN name is used and the DomainName parameter is set, the FQDN domain name must match. Required.
* **ContentPath**: The local content path for this folder member. Required.
* **StagingPath**: Ths staging path for this folder member. Optional.
* **ReadOnly**: Used to set this folder member to read only. Optional.
* **PrimaryMember**: Used to configure this as the Primary Member. Every folder must have at least one primary member for initial replication to take place. Default to false. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### Examples
Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains two folders called Software and Misc. An automatic Full Mesh connection topology will be assigned. The Content Paths for each folder and member will be set to 'd:\public\software' and 'd:\public\misc' respectively:
```powershell
configuration Sample_xDFSReplicationGroup_Simple
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -Module xDFS

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        # Configure the Replication Group
        xDFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software','Misc'
            Topology = 'Fullmesh'
            ContentPaths = 'd:\public\software','d:\public\misc'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource
    } # End of Node
} # End of Configuration
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
Sample_xDFSReplicationGroup_Simple `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\Sample_xDFSReplicationGroup_Simple `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```

Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. A manual topology is assigned to the replication connections.
```powershell
configuration Sample_xDFSReplicationGroup
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -Module xDFS

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        # Configure the Replication Group
        xDFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2.contoso.com'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        xDFSReplicationGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1'
            DestinationComputerName = 'FileServer2'
            PSDSCRunAsCredential = $Credential
        } # End of xDFSReplicationGroupConnection Resource

        xDFSReplicationGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2'
            DestinationComputerName = 'FileServer1.contoso.com'
            PSDSCRunAsCredential = $Credential
        } # End of xDFSReplicationGroupConnection Resource

        xDFSReplicationGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroup]RGPublic'
        } # End of RGPublic Resource

        xDFSReplicationGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        xDFSReplicationGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
Sample_xDFSReplicationGroup `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\Sample_xDFSReplicationGroup `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```


Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. An automatic fullmesh topology is assigned to the replication group connections.
```powershell
configuration Sample_xDFSReplicationGroup_FullMesh
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -Module xDFS

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        # Configure the Replication Group
        xDFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software'
            Topology = 'Fullmesh'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        xDFSReplicationGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroup]RGPublic'
        } # End of RGPublic Resource

        xDFSReplicationGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        xDFSReplicationGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
Sample_xDFSReplicationGroup_FullMesh `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\Sample_xDFSReplicationGroup_FullMesh `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```


## Namespace Resources
### xDFSNameSpace
**This resource has been deprecated. Please use xDFSNamespaceRoot and xDFSNamespaceFolder instead.**

### xDFSNamespaceRoot
This resource is used to create, edit or remove standalone or domain based DFS namespaces.  When the server is the last server in the namespace, the namespace itself will be removed.

#### Parameters
* **Path**: Specifies a path for the root of a DFS namespace. String. Required.
* **TargetPath**: Specifies a path for a root target of the DFS namespace. String. Required.
* **Ensure**: Specifies if the DFS Namespace root should exist. { Absent | Present }. String. Required.
* **Type**: Specifies the type of a DFS namespace as a Type object. { Standalone | DomainV1 | DomainV2 }. String. Required.
* **Description**: A description for the namespace. String. Optional.
* **TimeToLiveSec**: Specifies a TTL interval, in seconds, for referrals. Optional.
* **EnableSiteCosting**: Indicates whether a DFS namespace uses cost-based selection. Boolean. Optional.
* **EnableInsiteReferrals**: Indicates whether a DFS namespace server provides a client only with referrals that are in the same site as the client. Boolean. Optional.
* **EnableAccessBasedEnumeration**: Indicates whether a DFS namespace uses access-based enumeration. Boolean. Optional.
* **EnableRootScalability**: Indicates whether a DFS namespace uses root scalability mode. Boolean. Optional.
* **EnableTargetFailback**: Indicates whether a DFS namespace uses target failback. Boolean. Optional
* **ReferralPriorityClass**: Specifies the target priority class for a DFS namespace root. { Global-High | SiteCost-High | SiteCost-Normal | SiteCost-Low | Global-Low }. Optional.
* **ReferralPriorityRank**: Specifies the priority rank, as an integer, for a root target of the DFS namespace. Uint32. Optional

### xDFSNamespaceFolder
This resource is used to create, edit or remove folders from DFS namespaces.  When a target is the last target in a namespace folder, the namespace folder itself will be removed.

#### Parameters
* **Path**: Specifies a path for the DSF folder within an existing DFS Namespace. String. Required.
* **TargetPath**: Specifies a path for a target for the DFS namespace folder. String. Required.
* **Ensure**: Specifies if the DFS Namespace folder should exist. { Absent | Present }. String. Required.
* **Description**: A description for the namespace folder. String. Optional.
* **TimeToLiveSec**: Specifies a TTL interval, in seconds, for referrals. Optional.
* **EnableInsiteReferrals**: Indicates whether a DFS namespace server provides a client only with referrals that are in the same site as the client. Boolean. Optional.
* **EnableTargetFailback**: Indicates whether a DFS namespace uses target failback. Boolean. Optional
* **ReferralPriorityClass**: Specifies the target priority class for a DFS namespace folder. { Global-High | SiteCost-High | SiteCost-Normal | SiteCost-Low | Global-Low }. Optional.
* **ReferralPriorityRank**: Specifies the priority rank, as an integer, for a target in the DFS namespace. Uint32. Optional

### xDFSNamespaceServerConfiguration
This resource is used to configure DFS Namespace server settings. This is a single instance resource that can only be used once in a DSC Configuration.

#### Parameters
* **IsSingleInstance**: Specifies if the resource is a single instance, the value must be 'Yes'. Required.
* **LdapTimeoutSec**: Specifies a time-out value, in seconds, for Lightweight Directory Access Protocol (LDAP) requests for the DFS namespace server. Uint32. Optional.
* **SyncIntervalSec**: This interval controls how often domain-based DFS namespace root servers and domain controllers connect to the PDC emulator to get updates of DFS namespace metadata. Uint32. Optional.
* **UseFQDN**: Indicates whether a DFS namespace server uses FQDNs in referrals. Boolean.  Optional.

### Examples
Create an AD Domain V2 based DFS namespace called departments in the domain contoso.com with a single root target on the computer fs_1. Two subfolders are defined with targets that direct to shares on servers fs_3 and fs_8.
```powershell
Configuration DFSNamespace_Domain_SingleTarget
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        WindowsFeature DFS
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }

       # Configure the namespace
        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Departments
        {
            Path                 = '\\contoso.com\departments'
            TargetPath           = '\\fs_1\departments'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folders
        xDFSNamespaceFolder DFSNamespaceFolder_Domain_Finance
        {
            Path                 = '\\contoso.com\departments\finance'
            TargetPath           = '\\fs_3\Finance'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing finance files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_Management
        {
            Path                 = '\\contoso.com\departments\management'
            TargetPath           = '\\fs_8\Management'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing management files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource
    }
}
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Domain_SingleTarget `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Domain_SingleTarget `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```

Create an AD Domain V2 based DFS namespace called software in the domain contoso.com with a three targets on the servers ca-fileserver, ma-fileserver and ny-fileserver. It also creates a IT folder in each namespace.
```powershell
Configuration DFSNamespace_Domain_MultipleTarget
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        WindowsFeature DFS
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }

       # Configure the namespace
        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_CA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ca-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_MA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ma-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_NY
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ma-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_CA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ca-fileserver\it'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_MA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ma-fileserver\it'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_NY
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ma-fileserver\it'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource
    }
}
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Domain_MultipleTarget `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Domain_MultipleTarget `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```

Create a standalone DFS namespace called public on the server fileserver1. A namespace folder called Brochures is also created in this namespace that targets the \\fileserver2\brochures share.
```powershell
Configuration DFSNamespace_Standalone
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        WindowsFeature DFS
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }

       # Configure the namespace
        xDFSNamespaceRoot DFSNamespaceRoot_Standalone_Public
        {
            Path                 = '\\fileserver1\public'
            TargetPath           = '\\fileserver1\public'
            Ensure               = 'present'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folder
        xDFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1\public\brochures'
            TargetPath           = '\\fileserver2\brochures'
            Ensure               = 'present'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Standalone `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Standalone `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```

Create a standalone DFS namespace using FQDN called public on the server fileserver1.contoso.com. A namespace folder called Brochures is also created in this namespace that targets the \\fileserver2.contoso.com\brochures share.
```powershell
Configuration DFSNamespace_Standalone_FQDN
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = "Present"
            Name = "RSAT-DFS-Mgmt-Con"
        }

        WindowsFeature DFS
        {
            Name = 'FS-DFS-Namespace'
            Ensure = 'Present'
        }

       # Configure the namespace server
        xDFSNamespaceServerConfiguration DFSNamespaceConfig
        {
            IsSingleInstance          = 'Yes'
            UseFQDN                   = $true
            PsDscRunAsCredential      = $Credential
        } # End of xDFSNamespaceServerConfiguration Resource

       # Configure the namespace
        xDFSNamespaceRoot DFSNamespaceRoot_Standalone_Public
        {
            Path                 = '\\fileserver1.contoso.com\public'
            TargetPath           = '\\fileserver1.contoso.com\public'
            Ensure               = 'present'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folder
        xDFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1.contoso.com\public\brochures'
            TargetPath           = '\\fileserver2.contoso.com\brochures'
            Ensure               = 'present'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename        = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint      = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Standalone_FQDN `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Standalone_FQDN `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
```

## Versions
### Unreleased
* Converted AppVeyor.yml to pull Pester from PSGallery instead of Chocolatey.
* Changed AppVeyor.yml to use default image

### 3.1.0.0
* MSFT_xDFSNamespaceServerConfiguration- resource added.
* Corrected names of DFS Namespace sample files to indicate that they are setting Namespace roots and folders.
* Removed Pester version from AppVeyor.yml.

### 3.0.0.0
* RepGroup renamed to ReplicationGroup in all files.
* xDFSReplicationGroupConnection- Changed DisableConnection parameter to EnsureEnabled.
                                  Changed DisableRDC parameter to EnsureRDCEnabled.
* xDFSReplicationGroup- Fixed bug where disabled connection was not enabled in Fullmesh topology.

### 2.2.0.0
* DSC Module moved to MSFT.
* MSFT_xDFSNamespace- Removed.

### 2.1.0.0
* MSFT_xDFSRepGroup- Fixed issue when using FQDN member names.
* MSFT_xDFSRepGroupMembership- Fixed issue with Get-TargetResource when using FQDN ComputerName.
* MSFT_xDFSRepGroupConnection- Fixed issue with Get-TargetResource when using FQDN SourceComputerName or FQDN DestinationComputerName.
* MSFT_xDFSNamespaceRoot- Added write support to TimeToLiveSec parameter.
* MSFT_xDFSNamespaceFolder- Added write support to TimeToLiveSec parameter.

### 2.0.0.0
* MSFT_xDFSNamespaceRoot- resource added.
* MSFT_xDFSNamespaceFolder- resource added.
* MSFT_xDFSNamespace- deprecated - use MSFT_xDFSNamespaceRoot instead.

### 1.5.1.0
* MSFT_xDFSNamespace- Add parameters:
    - EnableSiteCosting
    - EnableInsiteReferrals
    - EnableAccessBasedEnumeration
    - EnableRootScalability
    - EnableTargetFailback
    - ReferralPriorityClass
    - ReferralPriorityRank

### 1.5.0.0
* MSFT_xDFSNamespace- New sample files added.
* MSFT_xDFSNamespace- MOF parameter descriptions corrected.
* MSFT_xDFSNamespace- Rearchitected code.
* MSFT_xDFSNamespace- SMB Share is no longer removed when a namespace or target is removed.
* MSFT_xDFSNamespace- Removed SMB Share existence check.
* Documentation layout corrected.
* MSFT_xDFSRepGroup- Array Parameter output disabled in Get-TargetResource until [this issue](https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type) is resolved.

### 1.4.2.0
* MSFT_xDFSRepGroup- Fixed "Cannot bind argument to parameter 'DifferenceObject' because it is null." error.
* All Unit tests updated to use *_TestEnvironment functions in DSCResource.Tests\TestHelpers.psm1

### 1.4.1.0
* MSFT_xDFSNamespace- Renamed Sample_DcFSNamespace.ps1 to Sample_xDFSNamespace.
* MSFT_xDFSNamespace- Corrected Import-DscResouce in example.

### 1.4.0.0
* Community update by Erik Granneman
* New DSC recource xDFSNameSpace

### 1.3.2.0
* Documentation and Module Manifest Update only.

### 1.3.1.0
* xDFSRepGroupFolder- DfsnPath parameter added for setting DFS Namespace path mapping.

### 1.3.0.0
* xDFSRepGroup- If ContentPaths is set, PrimaryMember is set to first member in the Members array.
* xDFSRRepGroupMembership- PrimaryMembers property added so that Primary Member can be set.

### 1.2.1.0
* xDFSRepGroup- Fix to ContentPaths generation when more than one folder is provided.

### 1.2.0.0
* xDFSRepGroup- ContentPaths string array parameter.

### 1.1.0.0
* xDFSRepGroupConnection- Resource added.

### 1.0.0.0
* Initial release.
