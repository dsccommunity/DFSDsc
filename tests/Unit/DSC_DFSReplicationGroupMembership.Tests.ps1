[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSReplicationGroupMembership'

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
            DomainName = 'contoso.com'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
        }

        $replicationGroupMemberships = @(
            [PSObject]@{
                GroupName = $replicationGroup.GroupName
                DomainName = $replicationGroup.DomainName
                FolderName = $replicationGroup.Folders[0]
                ComputerName = $replicationGroup.Members[0]
                EnsureEnabled = 'Enabled'
                ContentPath = 'd:\public\software\'
                StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
                StagingPathQuotaInMB = 4096
                MinimumFileStagingSize = 'Size256KB'
                ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
                ConflictAndDeletedQuotaInMB = 4096
                ReadOnly = $False
                RemoveDeletedFiles = $False
                PrimaryMember = $True
                DfsnPath = "\\$($replicationGroup.Members[0])\$replicationGroup.Folders[0]"
            }
        )

        $mockReplicationGroupMembership = [PSObject]@{
            GroupName = $replicationGroupMemberships[0].GroupName
            DomainName = $replicationGroupMemberships[0].DomainName
            FolderName = $replicationGroupMemberships[0].FolderName
            ComputerName = $replicationGroupMemberships[0].ComputerName
            Enabled = ($replicationGroupMemberships[0].EnsureEnabled -eq 'Enabled')
            ContentPath = $replicationGroupMemberships[0].ContentPath
            StagingPath = $replicationGroupMemberships[0].StagingPath
            StagingPathQuotaInMB = $replicationGroupMemberships[0].StagingPathQuotaInMB
            MinimumFileStagingSize = $replicationGroupMemberships[0].MinimumFileStagingSize
            ConflictAndDeletedPath = $replicationGroupMemberships[0].ConflictAndDeletedPath
            ConflictAndDeletedQuotaInMB = $replicationGroupMemberships[0].ConflictAndDeletedQuotaInMB
            ReadOnly = $replicationGroupMemberships[0].ReadOnly
            RemoveDeletedFiles = $replicationGroupMemberships[0].RemoveDeletedFiles
            PrimaryMember = $replicationGroupMemberships[0].PrimaryMember
            DfsnPath = $replicationGroupMemberships[0].DfsnPath
        }

        Describe 'DSC_DFSReplicationGroupMembership\Get-TargetResource' {
            Context 'Replication group folder does not exist' {
                Mock Get-DfsrMembership

                It 'Should not throw error' {
                    {
                        $result = Get-TargetResource `
                            -GroupName $replicationGroupMemberships[0].GroupName `
                            -FolderName $replicationGroupMemberships[0].FolderName `
                            -ComputerName $replicationGroupMemberships[0].ComputerName
                    } | Should -Not -Throw
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Requested replication group does exist' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                            -GroupName $replicationGroupMemberships[0].GroupName `
                            -FolderName $replicationGroupMemberships[0].FolderName `
                            -ComputerName $replicationGroupMemberships[0].ComputerName

                    $result.GroupName | Should -Be $replicationGroupMemberships[0].GroupName
                    $result.FolderName | Should -Be $replicationGroupMemberships[0].FolderName
                    $result.ComputerName | Should -Be $replicationGroupMemberships[0].ComputerName
                    $result.EnsureEnabled | Should -Be $replicationGroupMemberships[0].EnsureEnabled
                    $result.ContentPath | Should -Be $replicationGroupMemberships[0].ContentPath
                    $result.StagingPath | Should -Be $replicationGroupMemberships[0].StagingPath
                    $result.StagingPathQuotaInMB | Should -Be $replicationGroupMemberships[0].StagingPathQuotaInMB
                    $result.MinimumFileStagingSize | Should -Be $replicationGroupMemberships[0].MinimumFileStagingSize
                    $result.ConflictAndDeletedPath | Should -Be $replicationGroupMemberships[0].ConflictAndDeletedPath
                    $result.ConflictAndDeletedQuotaInMB | Should -Be $replicationGroupMemberships[0].ConflictAndDeletedQuotaInMB
                    $result.ReadOnly | Should -Be $replicationGroupMemberships[0].ReadOnly
                    $result.RemoveDeletedFiles | Should -Be $replicationGroupMemberships[0].RemoveDeletedFiles
                    $result.PrimaryMember | Should -Be $replicationGroupMemberships[0].PrimaryMember
                    $result.DfsnPath | Should -Be $replicationGroupMemberships[0].DfsnPath
                    $result.DomainName | Should -Be $replicationGroupMemberships[0].DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Requested replication group does exist but ComputerName passed as FQDN' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource `
                            -GroupName $replicationGroupMemberships[0].GroupName `
                            -FolderName $replicationGroupMemberships[0].FolderName `
                            -ComputerName "$($replicationGroupMemberships[0].ComputerName).$($replicationGroupMemberships[0].DomainName)"

                    $result.GroupName | Should -Be $replicationGroupMemberships[0].GroupName
                    $result.FolderName | Should -Be $replicationGroupMemberships[0].FolderName
                    $result.ComputerName | Should -Be $replicationGroupMemberships[0].ComputerName
                    $result.EnsureEnabled | Should -Be $replicationGroupMemberships[0].EnsureEnabled
                    $result.ContentPath | Should -Be $replicationGroupMemberships[0].ContentPath
                    $result.StagingPath | Should -Be $replicationGroupMemberships[0].StagingPath
                    $result.StagingPathQuotaInMB | Should -Be $replicationGroupMemberships[0].StagingPathQuotaInMB
                    $result.MinimumFileStagingSize | Should -Be $replicationGroupMemberships[0].MinimumFileStagingSize
                    $result.ConflictAndDeletedPath | Should -Be $replicationGroupMemberships[0].ConflictAndDeletedPath
                    $result.ConflictAndDeletedQuotaInMB | Should -Be $replicationGroupMemberships[0].ConflictAndDeletedQuotaInMB
                    $result.ReadOnly | Should -Be $replicationGroupMemberships[0].ReadOnly
                    $result.RemoveDeletedFiles | Should -Be $replicationGroupMemberships[0].RemoveDeletedFiles
                    $result.PrimaryMember | Should -Be $replicationGroupMemberships[0].PrimaryMember
                    $result.DfsnPath | Should -Be $replicationGroupMemberships[0].DfsnPath
                    $result.DomainName | Should -Be $replicationGroupMemberships[0].DomainName
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupMembership\Set-TargetResource' {
            Context 'Replication group membership exists and has no differences' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
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
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ComputerName = "$($splat.ComputerName).$($splat.DomainName)"
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different EnsureEnabled' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.EnsureEnabled = 'Disabled'
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
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
                    $splat = $replicationGroupMemberships[0].Clone()
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
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPathQuotaInMB++
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different MinimumFileStagingSize' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.MinimumFileStagingSize = 'Size512KB'
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ConflictAndDeletedQuotaInMB' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ConflictAndDeletedQuotaInMB++
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ReadOnly = (-not $splat.ReadOnly)
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different RemoveDeletedFiles' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.RemoveDeletedFiles = (-not $splat.RemoveDeletedFiles)
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different Primary Member' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.PrimaryMember = (-not $splat.PrimaryMember)
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different DfsnPath' {
                Mock Set-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.DfsnPath = 'Different'
                    { Set-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSReplicationGroupMembership\Test-TargetResource' {
            Context 'Replication group membership does not exist' {
                Mock Get-DfsrMembership

                It 'Should not throw error' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    { Test-TargetResource @splat } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists and has no differences' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return true' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists and has no differences but ComputerName passed as FQDN' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return true' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ComputerName = "$($splat.ComputerName).$($splat.DomainName)"
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different EnsureEnabled' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.EnsureEnabled = 'Disabled'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ContentPath = 'Different'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPath' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPath = 'Different'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different StagingPathQuotaInMB' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.StagingPathQuotaInMB++
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different MinimumFileStagingSize' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.MinimumFileStagingSize = 'Size512KB'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ConflictAndDeletedQuotaInMB' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ConflictAndDeletedQuotaInMB++
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.ReadOnly = (-not $splat.ReadOnly)
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different RemoveDeletedFiles' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.RemoveDeletedFiles = (-not $splat.RemoveDeletedFiles)
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different PrimaryMember' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                # Return *true* - should not flag as changed required as cleared after initial sync
                It 'Should return true' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.PrimaryMember = (-not $splat.PrimaryMember)
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }

            Context 'Replication group membership exists but has different DfsnPath' {
                Mock Get-DfsrMembership -MockWith { return @($mockReplicationGroupMembership) }

                It 'Should return false' {
                    $splat = $replicationGroupMemberships[0].Clone()
                    $splat.Remove('ConflictAndDeletedPath')
                    $splat.DfsnPath = 'Different'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly -Times 1
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
