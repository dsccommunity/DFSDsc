<#
    .EXAMPLE
    Create a standalone DFS namespace using FQDN called public on the server
    fileserver1.contoso.com. A sub-folder called brochures is also created in
    this namespace that targets the \\fileserver2.contoso.com\brochures share.
#>
Configuration Example
{
    param
    (
        [Parameter()]
        [System.String[]]
        $NodeName = 'localhost',

        [Parameter()]
        [PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName 'xDFS'

    Node $NodeName
    {
        <#
            Install the Prerequisite features first
            Requires Windows Server 2012 R2 Full install
        #>
        WindowsFeature RSATDFSMgmtConInstall
        {
            Ensure = 'Present'
            Name = 'RSAT-DFS-Mgmt-Con'
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
            Ensure               = 'Present'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folder
        xDFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1.contoso.com\public\brochures'
            TargetPath           = '\\fileserver2.contoso.com\brochures'
            Ensure               = 'Present'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
