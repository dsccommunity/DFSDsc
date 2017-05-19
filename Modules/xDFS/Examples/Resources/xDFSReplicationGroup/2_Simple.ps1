<#
    .EXAMPLE
    Create a DFS Replication Group called Public containing two members, FileServer1
    and FileServer2. The Replication Group contains two folders called Software and Misc.
    An automatic Full Mesh connection topology will be assigned. The Content Paths for each
    folder and member will be set to 'd:\public\software' and 'd:\public\misc' respectively.
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

    Import-DscResource -Module xDFS

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

        # Configure the Replication Group
        xDFSReplicationGroup RGPublic
        {
            GroupName = 'Public'
            Description = 'Public files for use by all departments'
            Ensure = 'Present'
            Members = 'FileServer1','FileServer2'
            Folders = 'Software','Misc'
            Topology = 'Fullmesh'
            ContentPaths = 'd:\public\software','d:\public\misc'
            PSDSCRunAsCredential = $Credential
            DependsOn = '[WindowsFeature]RSATDFSMgmtConInstall'
        } # End of RGPublic Resource
    } # End of Node
} # End of Configuration
