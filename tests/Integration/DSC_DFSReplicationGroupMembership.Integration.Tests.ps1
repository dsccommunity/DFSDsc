<#
    These integration tests can only be run on a computer that:
    1. Is a member of an Active Directory domain.
    2. Has access to two Windows Server 2012 or greater servers with
    the FS-DFS-Replication and RSAT-DFS-Mgmt-Con features installed.
    3. An AD User account that has the required permissions that are needed
    to create a DFS Replication Group.

    If the above are available then to allow these tests to be run a
    DSC_DFSReplicationGroupMembership.config.json file must be created in the same folder as
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
$script:dscResourceName = 'DSC_DFSReplicationGroupMembership'

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
        Context 'When creating a DFS Replication Group Membership' {
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

                $script:replicationGroupMembership = @{
                    GroupName            = 'IntegrationTestReplicationGroup'
                    Folders              = $script:testConfig.Folders
                    FolderName           = $script:testConfig.Folders[0]
                    Members              = $script:testConfig.Members
                    ComputerName         = $script:testConfig.Members[0]
                    ContentPath          = $script:testConfig.ContentPaths[0]
                    ReadOnly             = $false
                    PrimaryMember        = $true
                    PSDSCRunAsCredential = $script:PSDscRunAsCredential
                }

                # Create the Replication group to work with
                New-DFSReplicationGroup `
                    -GroupName $script:replicationGroupMembership.GroupName

                foreach ($member in $script:replicationGroupMembership.Members)
                {
                    Add-DFSRMember `
                        -GroupName $script:replicationGroupMembership.GroupName `
                        -ComputerName $member
                }

                foreach ($folder in $script:replicationGroupMembership.Folders)
                {
                    New-DFSReplicatedFolder `
                        -GroupName $script:replicationGroupMembership.GroupName `
                        -FolderName $folder
                }
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName                    = 'localhost'
                                GroupName                   = $script:replicationGroupMembership.GroupName
                                FolderName                  = $script:replicationGroupMembership.FolderName
                                ComputerName                = $script:replicationGroupMembership.ComputerName
                                ContentPath                 = $script:replicationGroupMembership.ContentPath
                                ReadOnly                    = $script:replicationGroupMembership.ReadOnly
                                PrimaryMember               = $script:replicationGroupMembership.PrimaryMember
                                PSDSCRunAsCredential        = $script:replicationGroupMembership.PSDSCRunAsCredential
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
                $replicationGroupMembershipNew = Get-DfsrMembership `
                    -GroupName $script:replicationGroupMembership.GroupName `
                    -ComputerName $script:replicationGroupMembership.Members[0] `
                    -ErrorAction Stop | Where-Object -Property FolderName -eq $script:replicationGroupMembership.Folders[0]
                $replicationGroupMembershipNew.GroupName              | Should -Be $script:replicationGroupMembership.GroupName
                $replicationGroupMembershipNew.ComputerName           | Should -Be $script:replicationGroupMembership.Members[0]
                $replicationGroupMembershipNew.FolderName             | Should -Be $script:replicationGroupMembership.Folders[0]
                $replicationGroupMembershipNew.ContentPath            | Should -Be $script:replicationGroupMembership.ContentPath
                $replicationGroupMembershipNew.StagingPathQuotaInMB   | Should -Be $script:replicationGroupMembership.StagingPathQuotaInMB
                $replicationGroupMembershipNew.ReadOnly               | Should -Be $script:replicationGroupMembership.ReadOnly
                $replicationGroupMembershipNew.PrimaryMember          | Should -Be $script:replicationGroupMembership.PrimaryMember
            }
        }

        AfterAll {
            # Clean up
            Remove-DFSReplicationGroup `
                -GroupName $script:replicationGroupMembership.GroupName `
                -RemoveReplicatedFolders `
                -Force `
                -Confirm:$false
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
