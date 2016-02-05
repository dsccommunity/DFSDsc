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
        cDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_CA
        {
            Path                 = '\\contoso.com\software' 
            TargetPath           = '\\ca-fileserver\software'           
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        cDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_MA
        {
            Path                 = '\\contoso.com\software' 
            TargetPath           = '\\ma-fileserver\software'           
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        cDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_NY
        {
            Path                 = '\\contoso.com\software' 
            TargetPath           = '\\ma-fileserver\software'           
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        cDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_CA
        {
            Path                 = '\\contoso.com\software\it' 
            TargetPath           = '\\ca-fileserver\it'           
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of cDFSNamespaceFolder Resource

        cDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_MA
        {
            Path                 = '\\contoso.com\software\it' 
            TargetPath           = '\\ma-fileserver\it'           
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of cDFSNamespaceFolder Resource

        cDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_NY
        {
            Path                 = '\\contoso.com\software\it' 
            TargetPath           = '\\ma-fileserver\it'           
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of cDFSNamespaceFolder Resource
    }
}
