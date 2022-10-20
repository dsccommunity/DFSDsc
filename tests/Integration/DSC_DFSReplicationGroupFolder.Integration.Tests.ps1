<#
    These integration tests can only be run on a computer that:
    1. Is a member of an Active Directory domain.
    2. Has access to two Windows Server 2012 or greater servers with
    the FS-DFS-Replication and RSAT-DFS-Mgmt-Con features installed.
    3. An AD User account that has the required permissions that are needed
    to create a DFS Replication Group.

    If the above are available then to allow these tests to be run a
    DSC_DFSReplicationGroupFolder.config.json file must be created in the same folder as
    this file. The content should be a customized version of the following:
    {
        "Username":  "contoso.com\\Administrator",
        "Folders":  [
                        "TestFolder1",
                        "TestFolder2"
                    ],
        "Members":  [
                        "Server1",
                        "Server2"
                    ],
        "ContentPaths":  [
                        "c:\\IntegrationTests\\TestFolder1",
                        "c:\\IntegrationTests\\TestFolder2"
                    ],
        "Password":  "MyPassword"
    }

    If the above are available and configured these integration tests will run.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSReplicationGroupFolder'

# Test to see if the JSON config file is available.
$script:configJson = [System.IO.Path]::ChangeExtension($MyInvocation.MyCommand.Path,'json')

if (-not (Test-Path -Path $configJson))
{
    return
}

try
{
    Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
}
catch [System.IO.FileNotFoundException]
{
    throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
}

$script:testEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:dscModuleName `
    -DSCResourceName $script:dscResourceName `
    -ResourceType 'Mof' `
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

try
{
    # Ensure that the tests can be performed on this computer
    $productType = (Get-CimInstance Win32_OperatingSystem).ProductType
    Describe 'Environment' {
        Context 'Operating System' {
            It 'Should be a Server OS' {
                $productType | Should -Be 3
            }
        }
    }

    if ($productType -ne 3)
    {
        break
    }

    $featureInstalled = (Get-WindowsFeature -Name FS-DFS-Replication).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Replication Feature Installed' {
                $featureInstalled | Should -Be $true
            }
        }
    }

    if ($featureInstalled -eq $false)
    {
        break
    }

    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$($script:dscResourceName)_Integration" {
        Context 'When the creating a DFS Replication Group Folder' {
            BeforeAll {
                # If there is a .config.json file for these tests, read the test parameters from it.
                if (Test-Path -Path $script:configJson)
                {
                    $script:testConfig = Get-Content -Path $script:configJson | ConvertFrom-Json
                }
                else
                {
                    # Example config parameters.
                    $script:testConfig = @{
                        Username = 'contoso.com\Administrator'
                        Password = 'MyP@ssw0rd!1'
                        Members = @('Server1','Server1')
                        Folders = @('TestFolder1','TestFolder2')
                        ContentPaths = @("$(ENV:Temp)TestFolder1","$(ENV:Temp)TestFolder2")
                    }
                }

                $script:testPassword = ConvertTo-SecureString -String $script:testConfig.Password -AsPlainText -Force
                $script:PSDscRunAsCredential = New-Object `
                    -TypeName System.Management.Automation.PSCredential `
                    -ArgumentList ($script:testConfig.Username, $script:testPassword)

                $script:replicationGroupFolder = @{
                    GroupName               = 'IntegrationTestReplicationGroup'
                    Folders                 = $script:testConfig.Folders
                    Members                 = $script:testConfig.Members
                    FolderName              = $script:testConfig.Folders[0]
                    Description             = "Integration Test Rep Group Folder $($script:testConfig.Folders[0])"
                    DirectoryNameToExclude  = @('Temp')
                    FilenameToExclude       = @('*.bak','*.tmp')
                    PSDSCRunAsCredential    = $script:PSDscRunAsCredential
                }

                # Create the Replication group to work with
                New-DFSReplicationGroup `
                    -GroupName $script:replicationGroupFolder.GroupName

                foreach ($Member in $script:replicationGroupFolder.Members)
                {
                    Add-DFSRMember `
                        -GroupName $script:replicationGroupFolder.GroupName `
                        -ComputerName $Member
                }

                foreach ($Folder in $script:replicationGroupFolder.Folders)
                {
                    New-DFSReplicatedFolder `
                        -GroupName $script:replicationGroupFolder.GroupName `
                        -FolderName $Folder
                }
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName                    = 'localhost'
                                GroupName                   = $script:replicationGroupFolder.GroupName
                                FolderName                  = $script:replicationGroupFolder.FolderName
                                Description                 = $script:replicationGroupFolder.Description
                                DirectoryNameToExclude      = $script:replicationGroupFolder.DirectoryNameToExclude
                                FilenameToExclude           = $script:replicationGroupFolder.FilenameToExclude
                                PSDSCRunAsCredential        = $script:replicationGroupFolder.PSDSCRunAsCredential
                                PSDscAllowPlainTextPassword = $true
                            }
                        )
                    }

                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData

                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ComputerName localhost `
                        -Wait `
                        -Verbose `
                        -Force `
                        -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should have set the resource and all the parameters should match' {
                $replicationGroupFolderNew = Get-DfsReplicatedFolder `
                    -GroupName $script:replicationGroupFolder.GroupName `
                    -FolderName $script:replicationGroupFolder.FolderName `
                    -ErrorAction Stop
                $replicationGroupFolderNew.GroupName              | Should -Be $script:replicationGroupFolder.GroupName
                $replicationGroupFolderNew.FolderName             | Should -Be $script:replicationGroupFolder.FolderName
                $replicationGroupFolderNew.Description            | Should -Be $script:replicationGroupFolder.Description
                $replicationGroupFolderNew.DirectoryNameToExclude | Should -Be $script:replicationGroupFolder.DirectoryNameToExclude
                $replicationGroupFolderNew.FilenameToExclude      | Should -Be $script:replicationGroupFolder.FilenameToExclude
            }

            AfterAll {
                # Clean up
                Remove-DFSReplicationGroup `
                    -GroupName $script:replicationGroupFolder.GroupName `
                    -RemoveReplicatedFolders `
                    -Force `
                    -Confirm:$false
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
