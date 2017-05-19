$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroupConnection'

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xDFS'
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Unit
#endregion HEADER

# Begin Testing
try
{
    # Ensure that the tests can be performed on this computer
    $productType = (Get-CimInstance Win32_OperatingSystem).ProductType
    Describe 'Environment' {
        Context 'Operating System' {
            It 'should be a Server OS' {
                $productType | Should Be 3
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
            It 'should have the DFS Replication Feature Installed' {
                $featureInstalled | Should Be $true
            }
        }
    }

    if ($featureInstalled -eq $false)
    {
        break
    }

    $featureInstalled = (Get-WindowsFeature -Name RSAT-DFS-Mgmt-Con).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'should have the DFS Management Tools Feature Installed' {
                $featureInstalled | Should Be $true
            }
        }
    }
    if ($featureInstalled -eq $false)
    {
        break
    }

    #region Pester Tests
    InModuleScope $script:DSCResourceName {

        # Create the Mock Objects that will be used for running tests
        $ReplicationGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }

        $ReplicationGroupConnections = @(
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $ReplicationGroup.Members[0]
                DestinationComputerName = $ReplicationGroup.Members[1]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                DomainName = 'CONTOSO.COM'
            },
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $ReplicationGroup.Members[1]
                DestinationComputerName = $ReplicationGroup.Members[0]
                Ensure = 'Present'
                Description = 'Connection Description'
                EnsureEnabled = 'Enabled'
                EnsureRDCEnabled = 'Enabled'
                DomainName = 'CONTOSO.COM'
            }
        )

        $ReplicationGroupConnectionDisabled = $ReplicationGroupConnections[0].Clone()
        $ReplicationGroupConnectionDisabled.EnsureEnabled = 'Disabled'

        $MockReplicationGroupConnection = [PSObject]@{
            GroupName = $ReplicationGroupConnections[0].GroupName
            SourceComputerName = $ReplicationGroupConnections[0].SourceComputerName
            DestinationComputerName = $ReplicationGroupConnections[0].DestinationComputerName
            Description = $ReplicationGroupConnections[0].Description
            Enabled = ($ReplicationGroupConnections[0].EnsureEnabled -eq 'Enabled')
            RDCEnabled = ($ReplicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
            DomainName = $ReplicationGroupConnections[0].DomainName
        }

        Describe "MSFT_xDFSReplicationGroupConnection\Get-TargetResource" {
            Context 'No replication group connections exist' {
                Mock Get-DfsrConnection

                It 'should return absent replication group connection' {
                    $result = Get-TargetResource `
                        -GroupName $ReplicationGroupConnections[0].GroupName `
                        -SourceComputerName $ReplicationGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $ReplicationGroupConnections[0].DestinationComputerName `
                        -Ensure Present
                    $result.Ensure | Should Be 'Absent'
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Requested replication group connection does exist' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }

                It 'should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $ReplicationGroupConnections[0].GroupName `
                        -SourceComputerName $ReplicationGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $ReplicationGroupConnections[0].DestinationComputerName `
                        -Ensure Present

                    $result.Ensure | Should Be 'Present'
                    $result.GroupName | Should Be $ReplicationGroupConnections[0].GroupName
                    $result.SourceComputerName | Should Be $ReplicationGroupConnections[0].SourceComputerName
                    $result.DestinationComputerName | Should Be $ReplicationGroupConnections[0].DestinationComputerName
                    $result.Description | Should Be $ReplicationGroupConnections[0].Description
                    $result.EnsureEnabled | Should Be $ReplicationGroupConnections[0].EnsureEnabled
                    $result.EnsureRDCEnabled | Should Be $ReplicationGroupConnections[0].EnsureRDCEnabled
                    $result.DomainName | Should Be $ReplicationGroupConnections[0].DomainName
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Requested replication group connection does exist but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }

                It 'should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $ReplicationGroupConnections[0].GroupName `
                        -SourceComputerName "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)" `
                        -DestinationComputerName "$($ReplicationGroupConnections[0].DestinationComputerName).$($ReplicationGroupConnections[0].DomainName)" `
                        -Ensure Present

                    $result.Ensure | Should Be 'Present'
                    $result.GroupName | Should Be $ReplicationGroupConnections[0].GroupName
                    $result.SourceComputerName | Should Be $ReplicationGroupConnections[0].SourceComputerName
                    $result.DestinationComputerName | Should Be $ReplicationGroupConnections[0].DestinationComputerName
                    $result.Description | Should Be $ReplicationGroupConnections[0].Description
                    $result.EnsureEnabled | Should Be $ReplicationGroupConnections[0].EnsureEnabled
                    $result.EnsureRDCEnabled | Should Be $ReplicationGroupConnections[0].EnsureRDCEnabled
                    $result.DomainName | Should Be $ReplicationGroupConnections[0].DomainName
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroupConnection\Set-TargetResource" {
            Context 'Replication Group connection does not exist but should' {
                Mock Get-DfsrConnection
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group connection exists and there are no differences' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group connection exists and there are no differences but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        $splat.SourceComputerName = "$($splat.SourceComputerName).$($splat.DomainName)"
                        $splat.DestinationComputerName = "$($splat.DestinationComputerName).$($splat.DomainName)"
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group connection exists but has different Description' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group connection exists but has different EnsureEnabled' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        $splat.EnsureEnabled = 'Disabled'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group connection exists but has different EnsureRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        $splat.EnsureRDCEnabled = 'Disabled'
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }


            Context 'Replication Group connection exists but should not' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group connection exists and is correct' {
                Mock Get-DfsrConnection -MockWith { return @($MockReplicationGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupConnections[0].Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroupConnection\Test-TargetResource" {
            Context 'Replication Group Connection does not exist but should' {
                Mock Get-DfsrConnection

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists and there are no differences' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists and there are no differences but ComputerNames passed as FQDN' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    $splat.SourceComputerName = "$($splat.SourceComputerName).$($splat.DomainName)"
                    $splat.DestinationComputerName = "$($splat.DestinationComputerName).$($splat.DomainName)"
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists but has different Description' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    $splat.Description = 'Changed'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists but has different EnsureEnabled' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    $splat.EnsureEnabled = 'Disabled'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists but has different EnsureRDCEnabled' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    $splat.EnsureRDCEnabled = 'Disabled'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists but should not' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return false' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists and is correct' {
                Mock Get-DfsrConnection -MockWith { @($MockReplicationGroupConnection) }

                It 'should return true' {
                    $splat = $ReplicationGroupConnections[0].Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
        }
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
