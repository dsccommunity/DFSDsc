Configuration DFSNamespace_Domain_SingleTarget
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
        xDFSNamespaceRoot DFSNamespaceRoot_Domain_Departments
        {
            Path                 = '\\contoso.com\departments' 
            TargetPath           = '\\fs_1\departments'
            Ensure               = 'present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

       # Configure the namespace folders
        xDFSNamespaceFolder DFSNamespaceFolder_Domain_Finance
        {
            Path                 = '\\contoso.com\departments\finance' 
            TargetPath           = '\\fs_3\Finance'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing finance files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of xDFSNamespaceFolder Resource

        xDFSNamespaceFolder DFSNamespaceFolder_Domain_Management
        {
            Path                 = '\\contoso.com\departments\management' 
            TargetPath           = '\\fs_8\Management'
            Ensure               = 'present'
            Description          = 'AD Domain based DFS namespace folder for storing management files'
            TimeToLiveSec        = 600
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
DFSNamespace_Domain_SingleTarget `
    -configurationData $ConfigData `
    -Credential (Get-Credential -Message "Domain Credentials")
Start-DscConfiguration `
    -Wait `
    -Force `
    -Verbose `
    -ComputerName $ComputerName `
    -Path $PSScriptRoot\DFSNamespace_Domain_SingleTarget `
    -Credential (Get-Credential -Message "Local Admin Credentials on Remote Machine")
