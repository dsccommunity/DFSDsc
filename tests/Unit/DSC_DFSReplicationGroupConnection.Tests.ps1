[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSReplicationGroupConnection'

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
                $featureInstalled | Should -BeTrue
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
            Topology = 'Manual'
            DomainName = 'contoso.com'
        }

        $replicationGroupConnections = @(
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $replicationGroup.Members[0]
                DestinationComputerName = $replicationGroup.Members[1]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                EnsureCrossFileRDCEnabled = 'Enabled'
                MinimumRDCFileSizeInKB = 64
                DomainName = 'contoso.com'
            },
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $replicationGroup.Members[1]
                DestinationComputerName = $replicationGroup.Members[0]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                EnsureCrossFileRDCEnabled = 'Enabled'
                MinimumRDCFileSizeInKB = 64
                DomainName = 'contoso.com'
            }
        )

        $replicationGroupConnectionDisabled = $replicationGroupConnections[0].Clone()
        $replicationGroupConnectionDisabled.EnsureEnabled = 'Disabled'

        $mockReplicationGroupConnection = [PSObject]@{
            GroupName = $replicationGroupConnections[0].GroupName
            SourceComputerName = $replicationGroupConnections[0].SourceComputerName
            DestinationComputerName = $replicationGroupConnections[0].DestinationComputerName
            Description = $replicationGroupConnections[0].Description
            Enabled = ($replicationGroupConnections[0].EnsureEnabled -eq 'Enabled')
            RDCEnabled = ($replicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
            CrossFileRDCEnabled = ($replicationGroupConnections[0].EnsureCrossFileRDCEnabled -eq 'Enabled')
            MinimumRDCFileSizeInKB = $replicationGroupConnections[0].MinimumRDCFileSizeInKB
            DomainName = $replicationGroupConnections[0].DomainName
        }

        Describe 'DSC_DFSReplicationGroupConnection\Get-TargetResource' {
            Context 'No replication group connections exist' {
                Mock Get-DfsrConnection

                It 'Should return absent replication group connection' {
                    $result = Get-TargetResource `
                        -GroupName $replicationGroupConnections[0].GroupName `
                        -SourceComputerName $replicationGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $replicationGroupConnections[0].DestinationComputerName `
                        -Ensure Present
                    $result.Ensure | Should -Be 'Absent'
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Requested replication group connection does exist' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $replicationGroupConnections[0].GroupName `
                        -SourceComputerName $replicationGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $replicationGroupConnections[0].DestinationComputerName `
                        -Ensure Present

                    $result.Ensure | Should -Be 'Present'
                    $result.GroupName | Should -Be $replicationGroupConnections[0].GroupName
                    $result.SourceComputerName | Should -Be $replicationGroupConnections[0].SourceComputerName
                    $result.DestinationComputerName | Should -Be $replicationGroupConnections[0].DestinationComputerName
                    $result.Description | Should -Be $replicationGroupConnections[0].Description
                    $result.EnsureEnabled | Should -Be $replicationGroupConnections[0].EnsureEnabled
                    $result.EnsureRDCEnabled | Should -Be $replicationGroupConnections[0].EnsureRDCEnabled
                    $result.EnsureCrossFileRDCEnabled | Should -Be $replicationGroupConnections[0].EnsureCrossFileRDCEnabled
                    $result.MinimumRDCFileSizeInKB | Should -Be $replicationGroupConnections[0].MinimumRDCFileSizeInKB
                    $result.DomainName | Should -Be $replicationGroupConnections[0].DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Requested replication group connection does exist but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $replicationGroupConnections[0].GroupName `
                        -SourceComputerName "$($replicationGroupConnections[0].SourceComputerName).$($replicationGroupConnections[0].DomainName)" `
                        -DestinationComputerName "$($replicationGroupConnections[0].DestinationComputerName).$($replicationGroupConnections[0].DomainName)" `
                        -Ensure Present

                    $result.Ensure | Should -Be 'Present'
                    $result.GroupName | Should -Be $replicationGroupConnections[0].GroupName
                    $result.SourceComputerName | Should -Be $replicationGroupConnections[0].SourceComputerName
                    $result.DestinationComputerName | Should -Be $replicationGroupConnections[0].DestinationComputerName
                    $result.Description | Should -Be $replicationGroupConnections[0].Description
                    $result.EnsureEnabled | Should -Be $replicationGroupConnections[0].EnsureEnabled
                    $result.EnsureRDCEnabled | Should -Be $replicationGroupConnections[0].EnsureRDCEnabled
                    $result.EnsureCrossFileRDCEnabled | Should -Be $replicationGroupConnections[0].EnsureCrossFileRDCEnabled
                    $result.MinimumRDCFileSizeInKB | Should -Be $replicationGroupConnections[0].MinimumRDCFileSizeInKB
                    $result.DomainName | Should -Be $replicationGroupConnections[0].DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupConnection\Set-TargetResource' {
            Context 'Replication Group connection does not exist but should' {
                Mock Get-DfsrConnection
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists and there are no differences' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists and there are no differences but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.SourceComputerName = "$($splat.SourceComputerName).$($splat.DomainName)"
                        $splat.DestinationComputerName = "$($splat.DestinationComputerName).$($splat.DomainName)"
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but has different Description' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but has different EnsureEnabled' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.EnsureEnabled = 'Disabled'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but has different EnsureRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.EnsureRDCEnabled = 'Disabled'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but has different EnsureCrossFileRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.EnsureCrossFileRDCEnabled = 'Disabled'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but has different MinimumRDCFileSizeInKB' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.MinimumRDCFileSizeInKB++
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }

            Context 'Replication Group connection exists but should not' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group connection exists and is correct' {
                Mock Get-DfsrConnection -MockWith { return @($mockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'Should not throw error' {
                    {
                        $splat = $replicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly -Times 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly -Times 0
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupConnection\Test-TargetResource' {
            Context 'Replication Group Connection does not exist but should' {
                Mock Get-DfsrConnection

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists and there are no differences' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists and there are no differences but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.SourceComputerName = "$($splat.SourceComputerName).$($splat.DomainName)"
                    $splat.DestinationComputerName = "$($splat.DestinationComputerName).$($splat.DomainName)"
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but has different Description' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.Description = 'Changed'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but has different EnsureEnabled' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.EnsureEnabled = 'Disabled'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but has different EnsureRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.EnsureRDCEnabled = 'Disabled'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but has different EnsureCrossFileRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.EnsureCrossFileRDCEnabled = 'Disabled'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but has different MinimumRDCFileSizeInKB' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.MinimumRDCFileSizeInKB++
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists but should not' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return false' {
                    $splat = $replicationGroupConnections[0].Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }

            Context 'Replication Group Connection exists and is correct' {
                Mock Get-DfsrConnection -MockWith { @($mockReplicationGroupConnection) }

                It 'Should return true' {
                    $splat = $replicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly -Times 1
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
