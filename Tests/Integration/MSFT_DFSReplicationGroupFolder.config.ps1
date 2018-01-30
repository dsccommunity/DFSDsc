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

$ReplicationGroupFolder = @{
    GroupName               = 'IntegrationTestReplicationGroup'
    Folders                 = $TestConfig.Folders
    Members                 = $TestConfig.Members
    FolderName              = $TestConfig.Folders[0]
    Description             = "Integration Test Rep Group Folder $($TestConfig.Folders[0])"
    DirectoryNameToExclude  = @('Temp')
    FilenameToExclude       = @('*.bak','*.tmp')
    PSDSCRunAsCredential    = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, $TestPassword)
}

Configuration MSFT_DFSReplicationGroupFolder_Config {
    Import-DscResource -ModuleName DFSDsc
    node localhost {
        DFSReplicationGroupFolder Integration_Test {
            GroupName                   = $ReplicationGroupFolder.GroupName
            FolderName                  = $ReplicationGroupFolder.FolderName
            Description                 = $ReplicationGroupFolder.Description
            DirectoryNameToExclude      = $ReplicationGroupFolder.DirectoryNameToExclude
            FilenameToExclude           = $ReplicationGroupFolder.FilenameToExclude
            PSDSCRunAsCredential        = $ReplicationGroupFolder.PSDSCRunAsCredential
        }
    }
}
