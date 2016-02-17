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

$RepgroupMembership = @{
    GroupName              = 'IntegrationTestRepGroup'
    Folders                = $TestConfig.Folders
    FolderName             = $TestConfig.Folders[0]
    Members                = $TestConfig.Members
    ComputerName           = $TestConfig.Members[0]
    ContentPath            = $TestConfig.ContentPaths[0]
    ReadOnly               = $false
    PrimaryMember          = $true
    PSDSCRunAsCredential   = New-Object System.Management.Automation.PSCredential ($TestConfig.Username, (ConvertTo-SecureString $TestConfig.Password -AsPlainText -Force))
}

Configuration MSFT_xDFSRepGroupMembership_Config {
    Import-DscResource -ModuleName xDFS
    node localhost {
        xDFSRepGroupMembership Integration_Test {
            GroupName                   = $RepgroupMembership.GroupName
            FolderName                  = $RepgroupMembership.FolderName
            ComputerName                = $RepgroupMembership.ComputerName
            ContentPath                 = $RepgroupMembership.ContentPath
            ReadOnly                    = $RepgroupMembership.ReadOnly
            PrimaryMember               = $RepgroupMembership.PrimaryMember
            PSDSCRunAsCredential        = $RepgroupMembership.PSDSCRunAsCredential
        }
    }
}
