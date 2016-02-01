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
