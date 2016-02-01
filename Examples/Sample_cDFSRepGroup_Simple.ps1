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