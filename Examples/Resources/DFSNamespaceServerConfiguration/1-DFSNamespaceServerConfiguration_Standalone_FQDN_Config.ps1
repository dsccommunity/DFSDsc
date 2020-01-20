<#PSScriptInfo
.VERSION 1.0.0
.GUID ea6fb120-43ba-4a71-b77d-0e8b793c8ea3
.AUTHOR Microsoft Corporation
.COMPANYNAME Microsoft Corporation
.COPYRIGHT
.TAGS DSCConfiguration
.LICENSEURI https://github.com/PowerShell/DfsDsc/blob/master/LICENSE
.PROJECTURI https://github.com/PowerShell/DfsDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2016-Datacenter,2016-Datacenter-Server-Core
#>

#Requires -module DfsDsc

<#
    .DESCRIPTION
        Create a standalone DFS namespace using FQDN called public on the server
        fileserver1.contoso.com. A namespace folder called brochures is also created in this
        namespace that targets the \\fileserver2.contoso.com\brochures share.
#>
Configuration DFSNamespaceServerConfiguration_Standalone_FQDN_Config
{
    param
    (
        [Parameter()]
        [PSCredential]
        $Credential
    )

    Import-DscResource -ModuleName 'DFSDsc'

    Node localhost
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
        DFSNamespaceServerConfiguration DFSNamespaceConfig
        {
            IsSingleInstance          = 'Yes'
            UseFQDN                   = $true
            PsDscRunAsCredential      = $Credential
        } # End of DFSNamespaceServerConfiguration Resource

        # Configure the namespace
        DFSNamespaceRoot DFSNamespaceRoot_Standalone_Public
        {
            Path                 = '\\fileserver1.contoso.com\public'
            TargetPath           = '\\fileserver1.contoso.com\public'
            Ensure               = 'Present'
            State                = 'Online'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folder
        DFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1.contoso.com\public\brochures'
            TargetPath           = '\\fileserver2.contoso.com\brochures'
            Ensure               = 'Present'
            State                = 'Online'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
