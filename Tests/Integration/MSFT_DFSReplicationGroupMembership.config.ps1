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
    Foreach-Object { $Password.AppendChar( $_ ) }

$ReplicationGroupMembership = @{
    GroupName              = 'IntegrationTestReplicationGroup'
    Folders                = $TestConfig.Folders
    FolderName             = $TestConfig.Folders[0]
    Members                = $TestConfig.Members
    ComputerName           = $TestConfig.Members[0]
    ContentPath            = $TestConfig.ContentPaths[0]
    ReadOnly               = $false
    PrimaryMember          = $true
    PSDSCRunAsCredential   = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, $TestPassword)
}

Configuration MSFT_DFSReplicationGroupMembership_Config {
    Import-DscResource -ModuleName DFSDsc
    node localhost {
        DFSReplicationGroupMembership Integration_Test {
            GroupName                   = $ReplicationGroupMembership.GroupName
            FolderName                  = $ReplicationGroupMembership.FolderName
            ComputerName                = $ReplicationGroupMembership.ComputerName
            ContentPath                 = $ReplicationGroupMembership.ContentPath
            ReadOnly                    = $ReplicationGroupMembership.ReadOnly
            PrimaryMember               = $ReplicationGroupMembership.PrimaryMember
            PSDSCRunAsCredential        = $ReplicationGroupMembership.PSDSCRunAsCredential
        }
    }
}
