[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSReplicationGroupMember'

function Invoke-TestSetup
{
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
        -TestType 'Unit'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

# Begin Testing
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

    InModuleScope $script:dscResourceName {
        # Create the Mock Objects that will be used for running tests
        $replicationGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
            DomainName = 'contoso.com'
        }

        $mockReplicationGroupMember = @(
            [PSObject]@{
                GroupName = 'Test Group'
                ComputerName = $replicationGroup.Members[0]
                Ensure = 'Present'
                Description = 'Member Description'
                DomainName = 'contoso.com'
            },
            [PSObject]@{
                GroupName = 'Test Group'
                ComputerName = $replicationGroup.Members[1]
                Ensure = 'Present'
                Description = 'Member Description'
                DomainName = 'contoso.com'
            }
        )

        Describe 'DSC_DFSReplicationGroupMember\Get-TargetResource' {
            Context 'No replication group members exist' {
                Mock Get-DfsrMember

                It 'Should return absent replication group member' {
                    $result = Get-TargetResource `
                        -GroupName $mockReplicationGroupMember[0].GroupName `
                        -ComputerName $mockReplicationGroupMember[0].ComputerName `
                        -Ensure Present
                    $result.Ensure | Should -Be 'Absent'
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Requested replication group member does exist' {
                Mock Get-DfsrMember -MockWith { return @($mockReplicationGroupMember[0]) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $mockReplicationGroupMember[0].GroupName `
                        -ComputerName $mockReplicationGroupMember[0].ComputerName `
                        -Ensure Present

                    $result.Ensure | Should -Be 'Present'
                    $result.GroupName | Should -Be $mockReplicationGroupMember[0].GroupName
                    $result.ComputerName | Should -Be $mockReplicationGroupMember[0].ComputerName
                    $result.Description | Should -Be $mockReplicationGroupMember[0].Description
                    $result.DomainName | Should -Be $mockReplicationGroupMember[0].DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupMember\Set-TargetResource' {
            Context 'Replication Group member does not exist but should' {
                Mock Get-DfsrMember
                Mock Set-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember

                It 'Should not throw error' {
                    {
                        $splat = $mockReplicationGroupMember[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly -Times 0
                }
            }

            Context 'Replication Group member exists and there are no differences' {
                Mock Get-DfsrMember -MockWith { return @($mockReplicationGroupMember[0]) }
                Mock Set-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember

                It 'Should not throw error' {
                    {
                        $splat = $mockReplicationGroupMember[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly -Times 0
                }
            }

            Context 'Replication Group member exists but has different Description' {
                Mock Get-DfsrMember -MockWith { return @($mockReplicationGroupMember[0]) }
                Mock Set-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupMember[0].Clone()
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly -Times 0
                }
            }

            Context 'Replication Group member exists but should not' {
                Mock Get-DfsrMember -MockWith { return @($mockReplicationGroupMember[0]) }
                Mock Set-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember

                It 'Should not throw error' {
                    {
                        $splat = $mockReplicationGroupMember[0].Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Replication Group member exists and is correct' {
                Mock Get-DfsrMember -MockWith { return @($mockReplicationGroupMember[0]) }
                Mock Set-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember

                It 'Should not throw error' {
                    {
                        $splat = $mockReplicationGroupMember[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrMember -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly -Times 0
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupMember\Test-TargetResource' {
            Context 'Replication Group member does not exist but should' {
                Mock Get-DfsrMember

                It 'Should return false' {
                    $splat = $mockReplicationGroupMember[0].Clone()
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Replication Group member exists and there are no differences' {
                Mock Get-DfsrMember -MockWith { @($mockReplicationGroupMember[0]) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMember[0].Clone()
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Replication Group member exists but has different Description' {
                Mock Get-DfsrMember -MockWith { @($mockReplicationGroupMember[0]) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMember[0].Clone()
                    $splat.Description = 'Changed'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Replication Group member exists but should not' {
                Mock Get-DfsrMember -MockWith { @($mockReplicationGroupMember[0]) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMember[0].Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }

            Context 'Replication Group member exists and is correct' {
                Mock Get-DfsrMember -MockWith { @($mockReplicationGroupMember[0]) }

                It 'Should return true' {
                    $splat = $mockReplicationGroupMember[0].Clone()
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly -Times 1
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
