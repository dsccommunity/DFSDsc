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

$Repgroup = @{
    GroupName            = 'IntegrationTestRepGroup'
    Description          = 'Integration Test Replication Group'
    Ensure               = 'Present'
    Members              = $TestConfig.Members
    Folders              = $TestConfig.Folders
    Topology             = 'Fullmesh'
    PSDSCRunAsCredential = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, (ConvertTo-SecureString $TestConfig.Password -AsPlainText -Force))
}

Configuration BMD_cDFSRepGroup_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSRepGroup Integration_Test {
            GroupName                   = $RepGroup.GroupName
            Description                 = $RepGroup.Description
            Ensure                      = $RepGroup.Ensure
            Members                     = $RepGroup.Members
            Folders                     = $RepGroup.Folders
            ContentPaths                = $RepGroup.ContentPaths
            Topology                    = $RepGroup.Topology
            PSDSCRunAsCredential        = $RepGroup.PSDSCRunAsCredential
        }
    }
}
