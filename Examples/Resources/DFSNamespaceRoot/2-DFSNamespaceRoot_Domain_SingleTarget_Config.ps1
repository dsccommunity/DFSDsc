<#PSScriptInfo
.VERSION 1.0.0
.GUID ef7ea9b0-f02f-4352-bddd-16f9d40c3d66
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
        Create an AD Domain V2 based DFS namespace called departments in the domain contoso.com
        with a single root target on the computer fs_1. Two sub-folders are defined under the
        departments folder with targets that direct to shares on servers fs_3 and fs_8.
#>
Configuration DFSNamespaceRoot_Domain_SingleTarget_Config
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
        DFSNamespaceRoot DFSNamespaceRoot_Domain_Departments
        {
            Path                 = '\\contoso.com\departments'
            TargetPath           = '\\fs_1\departments'
            Ensure               = 'Present'
            Type                 = 'DomainV2'
            Description          = 'AD Domain based DFS namespace for storing departmental files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceRoot Resource

        # Configure the namespace folders
        DFSNamespaceFolder DFSNamespaceFolder_Domain_Finance
        {
            Path                 = '\\contoso.com\departments\finance'
            TargetPath           = '\\fs_3\Finance'
            Ensure               = 'Present'
            State                = 'Online'
            Description          = 'AD Domain based DFS namespace folder for storing finance files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource

        DFSNamespaceFolder DFSNamespaceFolder_Domain_Management
        {
            Path                 = '\\contoso.com\departments\management'
            TargetPath           = '\\fs_8\Management'
            Ensure               = 'Present'
            State                = 'Online'
            Description          = 'AD Domain based DFS namespace folder for storing management files'
            TimeToLiveSec        = 600
            PsDscRunAsCredential = $Credential
        } # End of DFSNamespaceFolder Resource
    }
}
