# If there is a .config.json file for these tests, read the test parameters from it.
$configFile = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Path,'json')
if (Test-Path -Path $configFile)
{
     $TestConfig = Get-Content -Path $configFile | ConvertFrom-Json
}
else
{
    # Example config parameters.
    $TestConfig = @{
        Username = 'contoso.com\Administrator'
        Password = 'MyP@ssw0rd!1'
        Members = @('Server1','Server1')
        Folders = @('TestFolder1','TestFolder2')
        ContentPaths = @("$(ENV:Temp)TestFolder1","$(ENV:Temp)TestFolder2")
    }
}

$TestPassword = New-Object -Type SecureString [char[]] $TestConfig.Password |
    ForEach-Object { $Password.AppendChar( $_ ) }

$ReplicationGroup = @{
    GroupName            = 'IntegrationTestReplicationGroup'
    Description          = 'Integration Test Replication Group'
    Ensure               = 'Present'
    Members              = $TestConfig.Members
    Folders              = $TestConfig.Folders
    Topology             = 'Fullmesh'
    PSDSCRunAsCredential = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, $TestPassword)
}

Configuration MSFT_DFSReplicationGroup_Config {
    Import-DscResource -ModuleName DFSDsc
    node localhost {
        DFSReplicationGroup Integration_Test {
            GroupName                   = $ReplicationGroup.GroupName
            Description                 = $ReplicationGroup.Description
            Ensure                      = $ReplicationGroup.Ensure
            Members                     = $ReplicationGroup.Members
            Folders                     = $ReplicationGroup.Folders
            ContentPaths                = $ReplicationGroup.ContentPaths
            Topology                    = $ReplicationGroup.Topology
            PSDSCRunAsCredential        = $ReplicationGroup.PSDSCRunAsCredential
        }
    }
}
