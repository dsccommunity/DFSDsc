<#PSScriptInfo
.VERSION 1.0.0
.GUID 53b67a3b-2508-490f-94e5-844d4be558f6
.AUTHOR DSC Community
.COMPANYNAME DSC Community
.COPYRIGHT Copyright the DSC Community contributors. All rights reserved.
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/DfsDsc/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/DfsDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2019-Datacenter,2019-Datacenter-Server-Core
#>

#Requires -module DfsDsc

<#
    .DESCRIPTION
        Create a DFS Replication Group called Public containing members defined separately,
        FileServer1 and FileServer2. The Replication Group contains a single folder called Software.
        A description will be set on the Software folder and it will be set to exclude the directory Temp
        from replication. Create a two-way connection between the two nodes.
#>
Configuration DFSReplicationGroup_Separate_Simple_Config
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
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGPublic Resource

        DFSReplicationGroupMember RGPublicMemberFS1
        {
            GroupName = 'Public'
            ComputerName = 'FileServer1'
            Ensure = 'Present'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroup]RGPublic'
        } # End of RGPublicMemberFS1 Resource

        DFSReplicationGroupMember RGPublicMemberFS2
        {
            GroupName = 'Public'
            ComputerName = 'FileServer2'
            Ensure = 'Present'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroup]RGPublic'
        } # End of RGPublicMemberFS2 Resource

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
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            StagingPathQuotaInMB = 4096
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupMember]RGPublicMemberFS1', '[DFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        DFSReplicationGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            StagingPathQuotaInMB = 4096
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupMember]RGPublicMemberFS2', '[DFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS2 Resource

        DFSReplicationGroupConnection "RGPublicConnectionFS1"
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1'
            DestinationComputerName = 'FileServer2'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicConnectionFS1 Resource
    } # End of Node
} # End of Configuration
