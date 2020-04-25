<#PSScriptInfo
.VERSION 1.0.0
.GUID 24104af9-3ba9-4926-9d0a-644be607e3a2
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/DfsDsc/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/DfsDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module DfsDsc

<#
    .DESCRIPTION
        Create a DFS Replication Group called Public containing two members, FileServer1 and
        FileServer2. The Replication Group contains a single folder called Software. A description
        will be set on the Software folder and it will be set to exclude the directory Temp from
        replication. The resource group topology is left set to 'Manual' so that the replication
        group connections can be defined.
#>
Configuration DFSReplicationGroupConnection_Complete_Config
{
    param
    (
        [Parameter()]
        [PSCredential]
        $Credential
    )

    Import-DscResource -Module DFSDsc

    Node localhost
    {
        <#
            Install the Prerequisite features first
            Requires Windows Server 2012 R2 Full install
        #>
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name = 'RSAT-DFS-Mgmt-Con'
        }

        # Configure the Replication Group
        DFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1.contoso.com','FileServer2.contoso.com'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGPublic Resource

        DFSReplicationGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1.contoso.com'
            DestinationComputerName = 'FileServer2.contoso.com'
            PSDSCRunAsCredential = $Credential
        } # End of DFSReplicationGroupConnection Resource

        DFSReplicationGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2.contoso.com'
            DestinationComputerName = 'FileServer1.contoso.com'
            PSDSCRunAsCredential = $Credential
        } # End of DFSReplicationGroupConnection Resource

        DFSReplicationGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroup]RGPublic'
        } # End of RGPublic Resource

        DFSReplicationGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1.contoso.com'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        DFSReplicationGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2.contoso.com'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS2 Resource
    } # End of Node
} # End of Configuration
