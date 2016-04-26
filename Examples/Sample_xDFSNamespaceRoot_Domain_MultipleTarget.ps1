```powershell
Configuration DFSNamespace_Domain_MultipleTarget
{
    param
    (
        [Parameter(Mandatory)]
        [pscredential] $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
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
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Domain_MultipleTarget `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Domain_MultipleTarget `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
