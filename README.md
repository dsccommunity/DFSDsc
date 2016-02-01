[![Build status](https://ci.appveyor.com/api/projects/status/tf23k8l44u1k3wnt/branch/master?svg=true)](https://ci.appveyor.com/project/PlagueHO/cdfs/branch/master)

# cDFS

The **cDFS** module contains DSC resources for configuring Distributed File System Replication and Namespaces. Currently in this version only Replication folders are supported. Namespaces will be supported in a future release.

## Requirements
* **Windows Management Framework 5.0**: Required because the PSDSCRunAsCredential DSC Resource parameter is needed.

## Installation
```powershell
Install-Module -Name cDFS -MinimumVersion 1.0.0.0
```

## Important Information
### DFSR Module
This DSC Resource requires that the DFSR PowerShell module is installed onto any computer this resource will be used on. This module is installed as part of RSAT tools or RSAT-DFS-Mgmt-Con Windows Feature in Windows Server 2012 R2.
However, this will automatically convert a Server Core installation into one containing the managment tools, which may not be ideal because it is no longer strictly a Server Core installation.
Because this DSC Resource actually only configures information within the AD, it is only required that this resource is run on a computer that is registered in AD. It doesn't need to be run on one of the File Servers participating
in the Distributed File System or Namespace.

### Domain Credentials
Because this resource is configuring information within Active Directory, the **PSDSCRunAsCredential** property must be used with a credential of a domain user that can work with DFS information. This means that this resource can only work on computers with Windows Management Framework 5.0 or above.


## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Replication Group Resources
### cDFSRepGroup
This resource is used to create, edit or remove DFS Replication Groups. If used to create a Replcation Group it should be combined with the cDFSRepGroupMembership resources.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group is either Absent or Present. Required.
* **Description**: A description for the Replication Group. Optional.
* **Members**: A list of computers that are members of this Replication Group. Optional.
* **Folders**: A list of folders that are replicated in this Replication Group. Optional.
* **Topology**: This allows a replication topology to assign to the Replication Group. It defaults to Manual, which will not automatically create a topology. If set to Fullmesh, a full mesh topology between all members will be created. Optional.
* **ContentPaths**: An array of DFS Replication Group Content Paths to use for each of the Folders. This can have one entry for each Folder in the Folders parameter and should be set in th same order. If any entry is not blank then the Content Paths will need to be set manually by using the cDFSRepGroupMembership resource. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### cDFSRepGroupConnection
This resource is used to create, edit and remove DFS Replication Group connections. This resource should ONLY be used if the Topology parameter in the Resource Group is set to Manual.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **Ensure**: Ensures that Replication Group connection is either Absent or Present. Required.
* **SourceComputerName**: The name of the Replication Group source computer for the connection. Required.
* **DestinationComputerName**: The name of the Replication Group destination computer for the connection. Required.
* **Description**: A description for the Replication Group connection. Optional.
* **DisableConnection**: Set to $true to disable this connection. Optional.
* **RDCDisable**: Set to $true to disable remote differention compression on this connection. Optional.
* **DomainName**: The AD domain the Replication Group connection should created in. Optional.

### cDFSRepGroupFolder
This resource is used to configure DFS Replication Group folders. This is an optional resource, and only needs to be used if the folder Description, FilenameToExclude or DirectoryNameToExclude fields need to be set. In most cases just setting the Folders property in the cDFSRepGroup resource will be acceptable.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The name of the Replication Group folder. Required.
* **Description**: A description for the Replication Group. Optional.
* **FilenameToExclude**: An array of file names to exclude from replication. Optional.
* **DirectoryNameToExclude**: An array of directory names to exclude from replication. Optional.
* **DfsnPath**: The DFS Namespace Path to this Replication Group folder is mapped to. This does NOT create the Namespace folders, it only sets the name in the folder object. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### cDFSRepGroupMembership
This resource is used to configure Replication Group Folder Membership. It is usually used to set the **ContentPath** for each Replication Group folder on each Member computer. It can also be used to set additional properties of the Membership. This resource shouldn't be used for folders where the Content Path is set in the cDFSRepGroup.

#### Parameters
* **GroupName**: The name of the Replication Group. Required.
* **FolderName**: The folder name of the Replication Group folder. Required.
* **ComputerName**: The computer name of the Replication Group member. Required.
* **ContentPath**: The local content path for this folder member. Required.
* **StagingPath**: Ths staging path for this folder member. Optional.
* **ReadOnly**: Used to set this folder member to read only. Optional.
* **PrimaryMember**: Used to configure this as the Primary Member. Every folder must have at least one primary member for intial replication to take place. Default to false. Optional.
* **DomainName**: The AD domain the Replication Group should created in. Optional.

### Examples
Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains two folders called Software and Misc. An automatic Full Mesh connection topology will be assigned. The Content Paths for each folder and member will be set to 'd:\public\software' and 'd:\public\misc' respectively:
```powershell
configuration Sample_cDFSRepGroup_Simple
{
    Import-DscResource -Module cDFS

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))

        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
        }

        # Configure the Replication Group
        cDFSRepGroup RGPublic
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
```

Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. A manual topology is assigned to the replication connections.
```powershell
configuration Sample_cDFSRepGroup
{
    Import-DscResource -Module cDFS

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))

        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
        }

        # Configure the Replication Group
        cDFSRepGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        cDFSRepGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1'
            DestinationComputerName = 'FileServer2'
            PSDSCRunAsCredential = $Credential
        } # End of cDFSRepGroupConnection Resource

        cDFSRepGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2'
            DestinationComputerName = 'FileServer1'
            PSDSCRunAsCredential = $Credential
        } # End of cDFSRepGroupConnection Resource

        cDFSRepGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroup]RGPublic'
        } # End of RGPublic Resource

        cDFSRepGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        cDFSRepGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
```


Create a DFS Replication Group called Public containing two members, FileServer1 and FileServer2. The Replication Group contains a single folder called Software. A description will be set on the Software folder and it will be set to exclude the directory Temp from replication. An automatic fullmesh topology is assigned to the replication group connections.
```powershell
configuration Sample_cDFSRepGroup_FullMesh
{
    Import-DscResource -Module cDFS

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))

        # Install the Prerequisite features first
        # Requires Windows Server 2012 R2 Full install
        WindowsFeature RSATDFSMgmtConInstall 
        { 
            Ensure = "Present" 
            Name = "RSAT-DFS-Mgmt-Con" 
        }

        # Configure the Replication Group
        cDFSRepGroup RGPublic
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

        cDFSRepGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroup]RGPublic'
        } # End of RGPublic Resource

        cDFSRepGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        cDFSRepGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[cDFSRepGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration
```


## Namespace Resources
### cDFSNameSpace
 This resource is used to create, edit or remove standalone or domain based DFS namespaces.  When the server is the last server in the namespace, the namespace itself will be removed. 

#### Parameters
* **Namespace**: The name of the namespace. Required.
* **Ensure**: Ensures that namespace is either Absent or Present. Required.
* **ComputerName**: The computer name of the namespace member. Default: Node Computer Name. Optional. 
* **DomainName**: The AD domain the namespace should created in. If not provided a standalone namespace will be created. Optional.
* **Description**: A description for the namespace. Optional.

### Examples
Create an AD Domain based DFS namespace called departments in the domain contoso.com with a single target on the computer fs_1.
```powershell
Configuration DFSNamespace_Domain_SingleTarget
{
    Import-DscResource -ModuleName 'cDFS'

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))    

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
        cDFSNamespace DFSNamespace_Domain_Departments
        {
            Namespace            = 'departments' 
            ComputerName         = 'fs_1'           
            Ensure               = 'present'
            DomainName           = 'contoso.com' 
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespace Resource
    }
}
```

Create an AD Domain based DFS namespace called software in the domain contoso.com with a three targets on the servers ca-fileserver, ma-fileserver and ny-fileserver.
```powershell
Configuration DFSNamespace_Domain_MultipleTarget
{
    Import-DscResource -ModuleName 'cDFS'

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))    

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
        cDFSNamespace DFSNamespace_Domain_Software_CA
        {
            Namespace            = 'software' 
            ComputerName         = 'ca-fileserver'           
            Ensure               = 'present'
            DomainName           = 'contoso.com' 
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespace Resource

        cDFSNamespace DFSNamespace_Domain_Software_MA
        {
            Namespace            = 'software' 
            ComputerName         = 'ma-fileserver'           
            Ensure               = 'present'
            DomainName           = 'contoso.com' 
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespace Resource

        cDFSNamespace DFSNamespace_Domain_Software_NY
        {
            Namespace            = 'software' 
            ComputerName         = 'ny-fileserver'           
            Ensure               = 'present'
            DomainName           = 'contoso.com' 
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespace Resource

    }
}
```

Create a standalone DFS namespace called public on the server fileserver1.
```powershell
Configuration DFSNamespace_Standalone_Public
{
    Import-DscResource -ModuleName 'cDFS'

    Node $NodeName
    {
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", (ConvertTo-SecureString $"MyP@ssw0rd!1" -AsPlainText -Force))    

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
        cDFSNamespace DFSNamespace_Standalone_Public
        {
            Namespace            = 'public'
            ComputerName         = 'fileserver1'
            Ensure               = 'present'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespace Resource
    }
}

```

## Future Features
* Add BMD_cDFSNamespaceFolder resource
* HWG_cDFSNamespace-
  - Add parameters:
    - EnableSiteCosting
    - EnableInsiteReferrals
    - EnableAccessBasedEnumeration
    - EnableRootScalability
    - EnableTargetFailback
    - ReferralPriorityClass
    - ReferralPriorityRank
  - Add support for DomainV1 namespaces
  
## Versions

### 1.5.0.0
* HWG_cDFSNamespace- New sample files added.
* HWG_cDFSNamespace- MOF parameter descriptions corrected.
* HWG_cDFSNamespace- Rearchitected code.
* HWG_cDFSNamespace- SMB Share is no longer removed when a namespace or target is removed.
* HWG_cDFSNamespace- Removed SMB Share existence check.
* Documentation layout corrected.
* BMD_cDFSRepGroup- Array Parameter output disabled in Get-TargetResource until [this issue](https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type) is resolved.

### 1.4.2.0
* BMD_cFDSRepGroup- Fixed "Cannot bind argument to parameter 'DifferenceObject' because it is null." error.
* All Unit tests updated to use *_TestEnvironment functions in DSCResource.Tests\TestHelpers.psm1

### 1.4.1.0
* HWG_cDFSNamespace- Renamed Sample_DcFSNamespace.ps1 to Sample_cDFSNamespace.
* HWG_cDFSNamespace- Corrected Import-DscResouce in example.

### 1.4.0.0
* Community update by Erik Granneman
* New DSC recource cDFSNameSpace

### 1.3.2.0
* Documentation and Module Manifest Update only.

### 1.3.1.0
* cDFSRepGroupFolder- DfsnPath parameter added for setting DFS Namespace path mapping.

### 1.3.0.0
* cDFSRepGroup- If ContentPaths is set, PrimaryMember is set to first member in the Members array.
* cDFSRRepGroupMembership- PrimaryMembers property added so that Primary Member can be set.

### 1.2.1.0
* cDFSRepGroup- Fix to ContentPaths generation when more than one folder is provided.

### 1.2.0.0
* cDFSRepGroup- ContentPaths string array parameter.

### 1.1.0.0
* cDFSRepGroupConnection- Resource added.

### 1.0.0.0
* Initial release.

## Links
* **[GitHub Repo](https://github.com/PlagueHO/cDFS)**: Raise any issues, requests or PRs here.
* **[My Blog](https://dscottraynsford.wordpress.com)**: See my PowerShell and Programming Blog.
