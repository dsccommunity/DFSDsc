$script:DSCModuleName   = 'DFSDsc'
$script:DSCResourceName = 'MSFT_DFSReplicationGroupMembership'

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

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

    $featureInstalled = (Get-WindowsFeature -Name RSAT-DFS-Mgmt-Con).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Management Tools Feature Installed' {
                $featureInstalled | Should -Be $true
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
        $replicationGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            DomainName = 'contoso.com'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
        }

        $mockReplicationGroupMembership = [PSObject]@{
            GroupName = $replicationGroup.GroupName
            DomainName = $replicationGroup.DomainName
            FolderName = $replicationGroup.Folders[0]
            ComputerName = $replicationGroup.Members[0]
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            StagingPathQuotaInMB = 4096
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
            PrimaryMember = $True
        }

        Describe 'MSFT_DFSReplicationGroupMembership\Get-TargetResource' {
            Context 'Replication group folder does not exist' {
                Mock Get-DfsrMembership

                It 'Should throw RegGroupFolderMissingError error' {
                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupMembershipMissingError) `
                        -f $mockReplicationGroupMembership.GroupName,$mockReplicationGroupMembership.FolderName,$mockReplicationGroupMembership.ComputerName)

                    {
                        $result = Get-TargetResource `
                            -GroupName $mockReplicationGroupMembership.GroupName `
                            -FolderName $mockReplicationGroupMembership.FolderName `
                            -ComputerName $mockReplicationGroupMembership.ComputerName
                    } | Should -Throw $errorRecord
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Requested replication group does exist' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                            -GroupName $mockReplicationGroupMembership.GroupName `
                            -FolderName $mockReplicationGroupMembership.FolderName `
                            -ComputerName $mockReplicationGroupMembership.ComputerName

                    $result.GroupName | Should -Be $mockReplicationGroupMembership.GroupName
                    $result.FolderName | Should -Be $mockReplicationGroupMembership.FolderName
                    $result.ComputerName | Should -Be $mockReplicationGroupMembership.ComputerName
                    $result.ContentPath | Should -Be $mockReplicationGroupMembership.ContentPath
                    $result.StagingPath | Should -Be $mockReplicationGroupMembership.StagingPath
                    $result.StagingPathQuotaInMB | Should -Be $mockReplicationGroupMembership.StagingPathQuotaInMB
                    $result.ConflictAndDeletedPath | Should -Be $mockReplicationGroupMembership.ConflictAndDeletedPath
                    $result.ReadOnly | Should -Be $mockReplicationGroupMembership.ReadOnly
                    $result.PrimaryMember | Should -Be $mockReplicationGroupMembership.PrimaryMember
                    $result.DomainName | Should -Be $mockReplicationGroupMembership.DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Requested replication group does exist but ComputerName passed as FQDN' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                            -GroupName $mockReplicationGroupMembership.GroupName `
                            -FolderName $mockReplicationGroupMembership.FolderName `
                            -ComputerName "$($mockReplicationGroupMembership.ComputerName).$($mockReplicationGroupMembership.DomainName)"

                    $result.GroupName | Should -Be $mockReplicationGroupMembership.GroupName
                    $result.FolderName | Should -Be $mockReplicationGroupMembership.FolderName
                    $result.ComputerName | Should -Be $mockReplicationGroupMembership.ComputerName
                    $result.ContentPath | Should -Be $mockReplicationGroupMembership.ContentPath
                    $result.StagingPath | Should -Be $mockReplicationGroupMembership.StagingPath
                    $result.StagingPathQuotaInMB | Should -Be $mockReplicationGroupMembership.StagingPathQuotaInMB
                    $result.ConflictAndDeletedPath | Should -Be $mockReplicationGroupMembership.ConflictAndDeletedPath
                    $result.ReadOnly | Should -Be $mockReplicationGroupMembership.ReadOnly
                    $result.PrimaryMember | Should -Be $mockReplicationGroupMembership.PrimaryMember
                    $result.DomainName | Should -Be $mockReplicationGroupMembership.DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_DFSReplicationGroupMembership\Set-TargetResource' {
            Context 'Replication group membership exists and has no differences' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists and has no differences but ComputerName passed as FQDN' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ComputerName = "$($splat.ComputerName).$($splat.DomainName)"
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ContentPath = 'Different'
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPath' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPath = 'Different'
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPathQuotaInMB' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPathQuotaInMB = 8192
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ReadOnly = (-not $splat.ReadOnly)
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different Primary Member' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.PrimaryMember = (-not $splat.PrimaryMember)
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_DFSReplicationGroupMembership\Test-TargetResource' {
            Context 'Replication group membership does not exist' {
                Mock Get-DfsrMembership

                It 'Should throw RegGroupMembershipMissingError error' {
                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupMembershipMissingError) -f `
                            $mockReplicationGroupMembership.GroupName,$mockReplicationGroupMembership.FolderName,$mockReplicationGroupMembership.ComputerName)

                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    { Test-TargetResource @splat } | Should -Throw $errorRecord
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists and has no differences' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return true' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists and has no differences but ComputerName passed as FQDN' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return true' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ComputerName = "$($splat.ComputerName).$($splat.DomainName)"
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ContentPath = 'Different'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPath' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPath = 'Different'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPathQuotaInMB' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPathQuotaInMB = 8192
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ReadOnly = (-not $splat.ReadOnly)
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different PrimaryMember' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $mockReplicationGroupMembership.Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.PrimaryMember = (-not $splat.PrimaryMember)
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
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
