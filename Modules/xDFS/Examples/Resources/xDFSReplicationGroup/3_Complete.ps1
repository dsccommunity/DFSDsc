<#
    .EXAMPLE
    Create a DFS Replication Group called Public containing two members, FileServer1 and
    FileServer2. The Replication Group contains a single folder called Software. A description
    will be set on the Software folder and it will be set to exclude the directory Temp from
    replication. The resource group topology is left set to 'Manual' so that the replication
    group connections can be defined.
#>
Configuration Example
{
    param
    (
        [Parameter()]
        [System.String[]]
        $NodeName = 'localhost',

        [Parameter()]
        [PSCredential]
        $Credential
    )

    Import-DscResource -Module xDFS

    Node $NodeName
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
        xDFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1.contoso.com','FileServer2.contoso.com'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGPublic Resource

        xDFSReplicationGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1.contoso.com'
            DestinationComputerName = 'FileServer2.contoso.com'
            PSDSCRunAsCredential = $Credential
        } # End of xDFSReplicationGroupConnection Resource

        xDFSReplicationGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2.contoso.com'
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
            ComputerName = 'FileServer1.contoso.com'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        xDFSReplicationGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2.contoso.com'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSReplicationGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS2 Resource
    } # End of Node
} # End of Configuration
