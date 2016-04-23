configuration Sample_xDFSReplicationGroup_Simple
{
    Import-DscResource -Module xDFS

    Node $NodeName
    {
        $Password = New-Object -Type SecureString [char[]] 'MyPassword' | % { $Password.AppendChar( $_ ) }
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", $Password)

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
