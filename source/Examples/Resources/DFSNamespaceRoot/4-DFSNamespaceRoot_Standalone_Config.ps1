<#PSScriptInfo
.VERSION 1.0.0
.GUID daadea0f-b395-4702-bc3d-0a0613e2ef9f
.AUTHOR DSC Community
.COMPANYNAME DSC Community
.COPYRIGHT Copyright the DSC Community contributors. All rights reserved.
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/DfsDsc/blob/main/LICENSE
.PROJECTURI https://github.com/dsccommunity/DfsDsc
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES First version.
.PRIVATEDATA 2019-Datacenter,2019-Datacenter-Server-Core
#>

#Requires -module DfsDsc

<#
    .DESCRIPTION
        Create a standalone DFS namespace called public on the server fileserver1. A namespace
        folder called brochures is also created in this namespace that targets the
        \\fileserver2\brochures share.
#>
Configuration DFSNamespaceRoot_Standalone_Config
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

        # Configure the namespace
        DFSNamespaceRoot DFSNamespaceRoot_Standalone_Public
        {
            Path                 = '\\fileserver1\public'
            TargetPath           = '\\fileserver1\public'
            Ensure               = 'Present'
            Type                 = 'Standalone'
            Description          = 'Standalone DFS namespace for storing public files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folder
        DFSNamespaceFolder DFSNamespaceFolder_Standalone_PublicBrochures
        {
            Path                 = '\\fileserver1\public\brochures'
            TargetPath           = '\\fileserver2\brochures'
            Ensure               = 'Present'
            Description          = 'Standalone DFS namespace for storing public brochure files'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
