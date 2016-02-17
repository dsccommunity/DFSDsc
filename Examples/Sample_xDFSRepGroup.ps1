configuration Sample_xDFSRepGroup
{
    Import-DscResource -Module xDFS

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
        xDFSRepGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2.contoso.com'
            Folders = 'Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = "[WindowsFeature]RSATDFSMgmtConInstall"
        } # End of RGPublic Resource

        xDFSRepGroupConnection RGPublicC1
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer1'
            DestinationComputerName = 'FileServer2'
            PSDSCRunAsCredential = $Credential
        } # End of xDFSRepGroupConnection Resource

        xDFSRepGroupConnection RGPublicC2
        {
            GroupName = 'Public'
            Ensure = 'Present'
            SourceComputerName = 'FileServer2'
            DestinationComputerName = 'FileServer1.contoso.com'
            PSDSCRunAsCredential = $Credential
        } # End of xDFSRepGroupConnection Resource

        xDFSRepGroupFolder RGSoftwareFolder
        {
            GroupName = 'Public'
            FolderName = 'Software'
            Description = 'DFS Share for storing software installers'
            DirectoryNameToExclude = 'Temp'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSRepGroup]RGPublic'
        } # End of RGSoftwareFolder Resource

        xDFSRepGroupMembership RGPublicSoftwareFS1
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer1'
            ContentPath = 'd:\Public\Software'
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSRepGroupFolder]RGSoftwareFolder'
        } # End of RGPublicSoftwareFS1 Resource

        xDFSRepGroupMembership RGPublicSoftwareFS2
        {
            GroupName = 'Public'
            FolderName = 'Software'
            ComputerName = 'FileServer2'
            ContentPath = 'e:\Data\Public\Software'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[xDFSRepGroupFolder]RGPublicSoftwareFS1'
        } # End of RGPublicSoftwareFS2 Resource

    } # End of Node
} # End of Configuration