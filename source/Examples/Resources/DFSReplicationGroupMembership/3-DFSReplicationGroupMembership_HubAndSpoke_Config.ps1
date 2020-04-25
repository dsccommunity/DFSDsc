<#PSScriptInfo
.VERSION 1.0.0
.GUID 52fb2644-0ad3-47f8-9ffa-aa7179d2a44a
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
        Create a Hub and Spoke style DFS Replication Group called WebSite
        containing one Hub member and one or more Spoke members. The name of
        the Hub computer is passed in the HubComputerName parameter and
        defaults to 'Hub'. The Hub member contains a folder called WebSiteFiles
        with the path 'd:\inetpub\wwwroot\WebSiteFiles'. This path is
        replicated to all members of the SpokeComputerName parameter array
        into the 'd:\inetpub\wwwroot\WebSiteFiles' folder. The spoke
        computers are passed in the SpokeComputerName parameter and
        defaults to 'Spoke1', 'Spoke2' and 'Spoke3'.
#>
Configuration DFSReplicationGroupMembership_HubAndSpoke_Config
{
    param
    (
        [Parameter()]
        [PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $HubComputerName = 'Hub',

        [Parameter()]
        [System.String[]]
        $SpokeComputerName = @('Spoke1','Spoke2','Spoke3')
    )

    Import-DscResource -Module DFSDsc

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

        # Configure the Replication Group
        DFSReplicationGroup RGWebSite
        {
            GroupName = 'WebSite'
            Description = 'Files for web server'
            Ensure = 'Present'
            Members = @() + $HubComputerName + $SpokeComputerName
            Folders = 'WebSiteFiles'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGWebSite Resource

        DFSReplicationGroupFolder RGWebSiteFolder
        {
            GroupName = 'WebSite'
            FolderName = 'WebSiteFiles'
            Description = 'DFS Share for replicating web site files'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroup]RGWebSite'
        } # End of RGWebSiteFolder Resource

        DFSReplicationGroupMembership RGWebSiteMembershipHub
        {
            GroupName = 'WebSite'
            FolderName = 'WebSiteFiles'
            ComputerName = $HubComputerName
            ContentPath = 'd:\inetpub\wwwroot\WebSiteFiles'
            StagingPathQuotaInMB = 4096
            PrimaryMember = $true
            PSDSCRunAsCredential = $Credential
            DependsOn = '[DFSReplicationGroupFolder]RGWebSiteFolder'
        } # End of RGWebSiteMembershipHub Resource

        # Configure the connection and membership for each Spoke
        foreach ($spoke in $SpokeComputerName)
        {
            DFSReplicationGroupConnection "RGWebSiteConnection$spoke"
            {
                GroupName = 'WebSite'
                Ensure = 'Present'
                SourceComputerName = $HubComputerName
                DestinationComputerName = $spoke
                PSDSCRunAsCredential = $Credential
                DependsOn = '[DFSReplicationGroupFolder]RGWebSiteFolder'
            } # End of RGWebSiteConnection$spoke Resource

            DFSReplicationGroupMembership "RGWebSiteMembership$spoke"
            {
                GroupName = 'WebSite'
                FolderName = 'WebSiteFiles'
                ComputerName = $spoke
                ContentPath = 'd:\inetpub\wwwroot\WebSiteFiles'
                StagingPathQuotaInMB = 4096
                PSDSCRunAsCredential = $Credential
                DependsOn = "[DFSReplicationGroupConnection]RGWebSiteConnection$spoke"
            } # End of RGWebSiteMembership$spoke Resource
        }
    } # End of Node
} # End of Configuration
