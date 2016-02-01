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
