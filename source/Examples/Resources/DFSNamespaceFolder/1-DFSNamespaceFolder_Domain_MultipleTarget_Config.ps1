<#PSScriptInfo
.VERSION 1.0.0
.GUID c99703be-abb1-424a-a856-b69af295ccfe
.AUTHOR DSC Community
.COMPANYNAME DSC Community
.COPYRIGHT Copyright the DSC Community contributors. All rights reserved.
.TAGS DSCConfiguration
.LICENSEURI https://github.com/dsccommunity/DfsDsc/blob/master/LICENSE
.PROJECTURI https://github.com/dsccommunity/DfsDsc
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
        Create an AD Domain V2 based DFS namespace called software in the domain contoso.com with
        a three targets on the servers ca-fileserver, ma-fileserver and ny-fileserver. It also
        creates a IT folder in each namespace.
#>
Configuration DFSNamespaceFolder_Domain_MultipleTarget_Config
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
        DFSNamespaceRoot DFSNamespaceRoot_Domain_Software_CA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ca-fileserver\software'
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        DFSNamespaceRoot DFSNamespaceRoot_Domain_Software_MA
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ma-fileserver\software'
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        DFSNamespaceRoot DFSNamespaceRoot_Domain_Software_NY
        {
            Path                 = '\\contoso.com\software'
            TargetPath           = '\\ny-fileserver\software'
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        DFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_CA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ca-fileserver\it'
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource

        DFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_MA
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ma-fileserver\it'
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource

        DFSNamespaceFolder DFSNamespaceFolder_Domain_SoftwareIT_NY
        {
            Path                 = '\\contoso.com\software\it'
            TargetPath           = '\\ny-fileserver\it'
            Ensure               = 'Present'
            Description          = 'AD Domain based DFS namespace for storing IT specific software installers'
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
