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
        cDFSNamespaceRoot DFSNamespaceRoot_Domain_Departments
        {
            Path                 = '\\contoso.com\departments' 
            TargetPath           = '\\fs_1\departments'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folders
        cDFSNamespaceFolder DFSNamespaceFolder_Domain_Finance
        {
            Path                 = '\\contoso.com\departments\finance' 
            TargetPath           = '\\fs_3\Finance'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing finance files'
            PsDscRunAsCredential = $Credential
        } # End of cDFSNamespaceFolder Resource

        cDFSNamespaceFolder DFSNamespaceFolder_Domain_Management
        {
            Path                 = '\\contoso.com\departments\management' 
            TargetPath           = '\\fs_8\Management'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing management files'
            PsDscRunAsCredential = $Credential
        } # End of cDFSNamespaceFolder Resource
    }
}
