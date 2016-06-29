Configuration DFSNamespace_Standalone_FQDN
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

       # Configure the namespace server
        xDFSNamespaceServerConfiguration DFSNamespaceConfig
        {
            IsSingleInstance          = 'Yes'
            UseFQDN                   = $true
            PsDscRunAsCredential      = $Credential
        } # End of xDFSNamespaceServerConfiguration Resource

       # Configure the namespace
        xDFSNamespaceRoot DFSNamespaceRoot_Standalone_Public
        {
            Path                 = '\\fileserver1.contoso.com\public'
            TargetPath           = '\\fileserver1.contoso.com\public'
            Ensure               = 'present'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folder
        xDFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1.contoso.com\public\brochures'
            TargetPath           = '\\fileserver2.contoso.com\brochures'
            Ensure               = 'present'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
$ComputerName = Read-Host -Prompt 'Computer Name'
$ConfigData = @{
    AllNodes = @(
        @{
            Nodename        = $ComputerName
            CertificateFile = "C:\publicKeys\targetNode.cer"
            Thumbprint      = "AC23EA3A9E291A75757A556D0B71CBBF8C4F6FD8"
        }
    )
}
DFSNamespace_Standalone_FQDN `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Standalone_FQDN `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
