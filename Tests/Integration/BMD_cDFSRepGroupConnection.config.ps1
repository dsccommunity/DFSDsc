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

$RepgroupConnection = @{
    GroupName               = 'IntegrationTestRepGroup'
    Folders                 = $TestConfig.Folders
    Members                 = $TestConfig.Members
    Ensure                  = 'Present'
    SourceComputerName      = $TestConfig.Members[0]
    DestinationComputerName = $TestConfig.Members[1]
    PSDSCRunAsCredential    = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, (ConvertTo-SecureString $TestConfig.Password -AsPlainText -Force))
}

Configuration BMD_cDFSRepGroupConnection_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSRepGroupConnection Integration_Test {
            GroupName                   = $RepgroupConnection.GroupName
            Ensure                      = 'Present'
            SourceComputerName          = $RepgroupConnection.SourceComputerName
            DestinationComputerName     = $RepgroupConnection.DestinationComputerName
            PSDSCRunAsCredential        = $RepgroupConnection.PSDSCRunAsCredential
        }
    }
}
