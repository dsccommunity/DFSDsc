# If there is a .config.json file for these tests, read the test parameters from it.
$ConfigFile = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Path,'json')
if (Test-Path -Path $ConfigFile)
{
     $TestConfig = Get-Content -Path $ConfigFile | ConvertFrom-Json
}
else
{
    # Example config parameters.
    $TestConfig = @{
        Username = 'CONTOSO.COM\Administrator'
        Password = 'MyP@ssw0rd!1'
        Members = @('Server1','Server1')
        Folders = @('TestFolder1','TestFolder2')
        ContentPaths = @("$(ENV:Temp)TestFolder1","$(ENV:Temp)TestFolder2")
    }
}

$ReplicationGroupFolder = @{
    GroupName               = 'IntegrationTestReplicationGroup'
    Folders                 = $TestConfig.Folders
    Members                 = $TestConfig.Members
    FolderName              = $TestConfig.Folders[0]
    Description             = "Integration Test Rep Group Folder $($TestConfig.Folders[0])"
    DirectoryNameToExclude  = @('Temp')
    FilenameToExclude       = @('*.bak','*.tmp')
    PSDSCRunAsCredential    = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, (ConvertTo-SecureString $TestConfig.Password -AsPlainText -Force))
}

Configuration MSFT_xDFSReplicationGroupFolder_Config {
    Import-DscResource -ModuleName xDFS
    node localhost {
        xDFSReplicationGroupFolder Integration_Test {
            GroupName                   = $ReplicationGroupFolder.GroupName
            FolderName                  = $ReplicationGroupFolder.FolderName
            Description                 = $ReplicationGroupFolder.Description
            DirectoryNameToExclude      = $ReplicationGroupFolder.DirectoryNameToExclude
            FilenameToExclude           = $ReplicationGroupFolder.FilenameToExclude
            PSDSCRunAsCredential        = $ReplicationGroupFolder.PSDSCRunAsCredential
        }
    }
}
