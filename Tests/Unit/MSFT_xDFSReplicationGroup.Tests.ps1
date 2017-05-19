$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroup'

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

        $ReplicationGroupAllFQDN = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2.CONTOSO.COM')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }

        $ReplicationGroupSomeDns = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2')
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

        $MockReplicationGroup = [PSObject]@{
            GroupName = $ReplicationGroup.GroupName
            DomainName = $ReplicationGroup.DomainName
            Description = $ReplicationGroup.Description
        }

        $MockReplicationGroupMember = @(
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                ComputerName = $ReplicationGroup.Members[0]
                DnsName = "$($ReplicationGroup.Members[0]).$($ReplicationGroup.DomainName)"
            },
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                ComputerName = $ReplicationGroup.Members[1]
                DnsName = "$($ReplicationGroup.Members[1]).$($ReplicationGroup.DomainName)"
            }
        )

        $MockReplicationGroupFolder = @(
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                FolderName = $ReplicationGroup.Folders[0]
                Description = 'Description 1'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            },
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                FolderName = $ReplicationGroup.Folders[1]
                Description = 'Description 2'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            }
        )

        $MockReplicationGroupMembership = [PSObject]@{
            GroupName = $ReplicationGroup.GroupName
            DomainName = $ReplicationGroup.DomainName
            FolderName = $ReplicationGroup.Folders[0]
            ComputerName = $ReplicationGroup.Members[0]
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
            PrimaryMember = $True
        }

        $MockReplicationGroupMembershipNotPrimary = $MockReplicationGroupMembership.Clone()
        $MockReplicationGroupMembershipNotPrimary.PrimaryMember = $False

        $MockReplicationGroupConnections = @(
            [PSObject]@{
                GroupName = $ReplicationGroupConnections[0].GroupName
                SourceComputerName = $ReplicationGroupConnections[0].SourceComputerName
                DestinationComputerName = $ReplicationGroupConnections[0].DestinationComputerName
                Description = $ReplicationGroupConnections[0].Description
                Enabled = ($ReplicationGroupConnections[0].EnsureEnabled -eq 'Enabled')
                RDCEnabled = ($ReplicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
                DomainName = $ReplicationGroupConnections[0].DomainName
            },
            [PSObject]@{
                GroupName = $ReplicationGroupConnections[1].GroupName
                SourceComputerName = $ReplicationGroupConnections[1].SourceComputerName
                DestinationComputerName = $ReplicationGroupConnections[1].DestinationComputerName
                Description = $ReplicationGroupConnections[1].Description
                Enabled = ($ReplicationGroupConnections[1].EnsureEnabled -eq 'Enabled')
                RDCEnabled = ($ReplicationGroupConnections[1].EnsureRDCEnabled -eq 'Enabled')
                DomainName = $ReplicationGroupConnections[1].DomainName
            }
        )

        $MockReplicationGroupConnectionDisabled = [PSObject]@{
            GroupName = $ReplicationGroupConnections[0].GroupName
            SourceComputerName = $ReplicationGroupConnections[0].SourceComputerName
            DestinationComputerName = $ReplicationGroupConnections[0].DestinationComputerName
            Description = $ReplicationGroupConnections[0].Description
            Enabled = $False
            RDCEnabled = ($ReplicationGroupConnections[0].EnsureRDCEnabled -eq 'Enabled')
            DomainName = $ReplicationGroupConnections[0].DomainName
        }

        $ReplicationGroupContentPath = $ReplicationGroup.Clone()
        $ReplicationGroupContentPath += @{ ContentPaths = @($MockReplicationGroupMembership.ContentPath) }

        Describe "MSFT_xDFSReplicationGroup\Get-TargetResource" {
            Context 'No replication groups exist' {
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder

                It 'should return absent replication group' {
                    $result = Get-TargetResource `
                        -GroupName $ReplicationGroup.GroupName `
                        -Ensure Present
                    $result.Ensure | Should Be 'Absent'
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Requested replication group does exist' {
                Mock Get-DfsReplicationGroup -MockWith { return @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $ReplicationGroup.GroupName `
                        -Ensure Present
                    $result.Ensure | Should Be 'Present'
                    $result.GroupName | Should Be $ReplicationGroup.GroupName
                    $result.Description | Should Be $ReplicationGroup.Description
                    $result.DomainName | Should Be $ReplicationGroup.DomainName
                    <#
                        Tests disabled until this issue is resolved:
                        https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    #>
                    if ($false) {
                        $result.Members | Should Be $ReplicationGroup.Members
                        $result.Folders | Should Be $ReplicationGroup.Folders
                    }
                }

                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                    <#
                        Tests disabled until this issue is resolved:
                        https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    #>
                    if ($false) {
                        Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                        Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    }
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Set-TargetResource" {
            Context 'Replication Group does not exist but should' {
                Mock Get-DfsReplicationGroup
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 2
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 2
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has different description' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Description = 'Changed'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but all Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupAllFQDN.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but some Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupSomeDns.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but is missing a member' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Members = @('FileServer2','FileServer1','FileServerNew')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has an extra member' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Members = @('FileServer2')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but is missing a folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Folders = @('Folder2','Folder1','FolderNew')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has an extra folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Folders = @('Folder2')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but should not' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has one missing connection' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has all connections missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 0
                }
            }

            Context 'Replication Group with Fullmesh topology exists and has a disabled connection' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection `
                    -MockWith { return $MockReplicationGroupConnectionDisabled } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroup.Clone()
                        $splat.Topology = 'Fullmesh'
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set but needs to be changed' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembership) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupContentPath.Clone()
                        $splat.ContentPaths = @('Different')
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and does not need to be changed' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembership) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupContentPath.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 0
                }
            }

            Context 'Replication Group Content Path is set and does not need to be changed but primarymember does' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembershipNotPrimary) }
                Mock Set-DfsrMembership

                It 'should not throw error' {
                    {
                        $splat = $ReplicationGroupContentPath.Clone()
                        Set-TargetResource @splat
                    } | Should Not Throw
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Set-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicationGroup -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName New-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsReplicatedFolder -Exactly 0
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Test-TargetResource" {
            Context 'Replication Group does not exist but should' {
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists but has different description' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Description = 'Changed'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but all Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroupAllFQDN.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but some Members passed as FQDN' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroupSomeDns.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but is missing a member' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Members = @('FileServer2','FileServer1','FileServerNew')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but has an extra member' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Members = @('FileServer2')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but is missing a folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Folders = @('Folder2','Folder1','FolderNew')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but has an extra folder' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Folders = @('Folder2')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but should not' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }

            Context 'Replication Group exists and is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }

                It 'should return true' {
                    $splat = $ReplicationGroup.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group Fullmesh Topology is required and correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }

                It 'should return true' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and one connection missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[0]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter { `
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and all connections missing' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }

                Mock Get-DfsrConnection `
                    -MockWith { } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Fullmesh Topology is required and connection is disabled' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrConnection `
                    -MockWith { return $MockReplicationGroupConnectionDisabled } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[0].SourceComputerName).$($ReplicationGroupConnections[0].DomainName)"
                    }
                Mock Get-DfsrConnection `
                    -MockWith { @($MockReplicationGroupConnections[1]) } `
                    -ParameterFilter {
                        $SourceComputerName -eq "$($ReplicationGroupConnections[1].SourceComputerName).$($ReplicationGroupConnections[1].DomainName)"
                    }

                It 'should return false' {
                    $splat = $ReplicationGroup.Clone()
                    $splat.Topology = 'Fullmesh'
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 2
                }
            }

            Context 'Replication Group Content Path is set and different' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembership) }

                It 'should return false' {
                    $splat = $ReplicationGroupContentPath.Clone()
                    $splat.ContentPaths = @('Different')
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and the same and PrimaryMember is correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembership) }

                It 'should return true' {
                    $splat = $ReplicationGroupContentPath.Clone()
                    Test-TargetResource @splat | Should Be $True
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication Group Content Path is set and the same and PrimaryMember is not correct' {
                Mock Get-DfsReplicationGroup -MockWith { @($MockReplicationGroup) }
                Mock Get-DfsrMember -MockWith { return $MockReplicationGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockReplicationGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockReplicationGroupMembershipNotPrimary) }

                It 'should return false' {
                    $splat = $ReplicationGroupContentPath.Clone()
                    Test-TargetResource @splat | Should Be $False
                }

                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroup\Get-FQDNMemberName" {
            Context 'ComputerName passed includes Domain Name that matches DomainName' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'CONTOSO.COM'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test.contoso.com'
                }
            }

            Context 'ComputerName passed includes Domain Name that does not match DomainName' {
                It 'should throw ReplicationGroupDomainMismatchError exception' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'NOTMATCH.COM'
                    }

                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupDomainMismatchError `
                        -f $splat.GroupName,$splat.ComputerName,$splat.DomainName))

                    { Get-FQDNMemberName @splat } | Should Throw $errorRecord
                }
            }

            Context 'ComputerName passed does not include Domain Name and DomainName was passed' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                        DomainName = 'CONTOSO.COM'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test.contoso.com'
                }
            }

            Context 'ComputerName passed does not include Domain Name and DomainName was not passed' {
                It 'should return correct FQDN' {
                    $splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                    }

                    Get-FQDNMemberName @splat | Should Be 'test'
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
