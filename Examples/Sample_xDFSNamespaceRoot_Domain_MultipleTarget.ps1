```powershell
Configuration DFSNamespace_Domain_MultipleTarget
{
    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        $Password = 'MyP@ssw0rd!1' | ConvertTo-SecureString -AsPlainText -Force
        [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ("CONTOSO.COM\Administrator", $Password)

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
        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_CA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ca-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_MA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ma-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Software_NY
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ma-fileserver\software'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_CA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ca-fileserver\it'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_MA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ma-fileserver\it'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_NY
        {
            Path                 = '\\contoso.com\software\it' 
            TargetPath           = '\\ma-fileserver\it'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource
    }
}
