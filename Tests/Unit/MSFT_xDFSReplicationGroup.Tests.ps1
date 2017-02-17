$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroup'

#region HEADER
# Unit Test Template Version: 1.1.0
[string] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xDFS'
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
    $ProductType = (Get-CimInstance Win32_OperatingSystem).ProductType
    Describe 'Environment' {
        Context 'Operating System' {
            It 'Should be a Server OS' {
                $ProductType | Should Be 3
            }
        }
    }
    if ($ProductType -ne 3)
    {
        Break
    }

    $Installed = (Get-WindowsFeature -Name FS-DFS-Replication).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Replication Feature Installed' {
                $Installed | Should Be $true
            }
        }
    }
    if ($Installed -eq $false)
    {
        Break
    }

    $Installed = (Get-WindowsFeature -Name RSAT-DFS-Mgmt-Con).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Management Tools Feature Installed' {
                $Installed | Should Be $true
            }
        }
    }
    if ($Installed -eq $false)
    {
        Break
    }

    #region Pester Tests
    InModuleScope $script:DSCResourceName {

        function New-TestException
        {
            [CmdLetBinding()]
            param
            (
                [Parameter(Mandatory)]
                [String] $errorId,

                [Parameter(Mandatory)]
                [System.Management.Automation.ErrorCategory] $errorCategory,

                [Parameter(Mandatory)]
                [String] $errorMessage
            )

            $exception = New-Object -TypeName System.Exception `
                -ArgumentList $errorMessage
            $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, $errorId, $errorCategory, $null

            return $errorRecord
        } # New-TestException

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
                    $Result = Get-TargetResource `
                        -GroupName $ReplicationGroup.GroupName `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Absent'
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
                    $Result = Get-TargetResource `
                        -GroupName $ReplicationGroup.GroupName `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Present'
                    $Result.GroupName | Should Be $ReplicationGroup.GroupName
                    $Result.Description | Should Be $ReplicationGroup.Description
                    $Result.DomainName | Should Be $ReplicationGroup.DomainName
                    # Tests disabled until this issue is resolved:
                    # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    # $Result.Members | Should Be $ReplicationGroup.Members
                    # $Result.Folders | Should Be $ReplicationGroup.Folders
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                    # Tests disabled until this issue is resolved:
                    # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    # Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    # Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
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
                        $Splat = $ReplicationGroup.Clone()
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Description = 'Changed'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroupAllFQDN.Clone()
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroupSomeDns.Clone()
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Members = @('FileServer2','FileServer1','FileServerNew')
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Members = @('FileServer2')
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Folders = @('Folder2','Folder1','FolderNew')
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Folders = @('Folder2')
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Topology = 'Fullmesh'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Topology = 'Fullmesh'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Topology = 'Fullmesh'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroup.Clone()
                        $Splat.Topology = 'Fullmesh'
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroupContentPath.Clone()
                        $Splat.ContentPaths = @('Different')
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroupContentPath.Clone()
                        Set-TargetResource @Splat
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
                        $Splat = $ReplicationGroupContentPath.Clone()
                        Set-TargetResource @Splat
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
                    $Splat = $ReplicationGroup.Clone()
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Description = 'Changed'
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroupAllFQDN.Clone()
                    Test-TargetResource @Splat | Should Be $True
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
                    $Splat = $ReplicationGroupSomeDns.Clone()
                    Test-TargetResource @Splat | Should Be $True
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Members = @('FileServer2','FileServer1','FileServerNew')
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Members = @('FileServer2')
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Folders = @('Folder2','Folder1','FolderNew')
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Folders = @('Folder2')
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    Test-TargetResource @Splat | Should Be $True
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Topology = 'Fullmesh'
                    Test-TargetResource @Splat | Should Be $True
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Topology = 'Fullmesh'
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Topology = 'Fullmesh'
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroup.Clone()
                    $Splat.Topology = 'Fullmesh'
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroupContentPath.Clone()
                    $Splat.ContentPaths = @('Different')
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = $ReplicationGroupContentPath.Clone()
                    Test-TargetResource @Splat | Should Be $True
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
                    $Splat = $ReplicationGroupContentPath.Clone()
                    Test-TargetResource @Splat | Should Be $False
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
                    $Splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'CONTOSO.COM'
                    }
                    Get-FQDNMemberName @Splat | Should Be 'test.contoso.com'
                }
            }
            Context 'ComputerName passed includes Domain Name that does not match DomainName' {
                It 'should throw ReplicationGroupDomainMismatchError exception' {
                    $Splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'NOTMATCH.COM'
                    }
                    $ExceptionParameters = @{
                        errorId = 'ReplicationGroupDomainMismatchError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.ReplicationGroupDomainMismatchError `
                            -f $Splat.GroupName,$Splat.ComputerName,$Splat.DomainName)
                    }
                    $Exception = New-TestException @ExceptionParameters
                    { Get-FQDNMemberName @Splat } | Should Throw $Exception
                }
            }
            Context 'ComputerName passed does not include Domain Name and DomainName was passed' {
                It 'should return correct FQDN' {
                    $Splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                        DomainName = 'CONTOSO.COM'
                    }
                    Get-FQDNMemberName @Splat | Should Be 'test.contoso.com'
                }
            }
            Context 'ComputerName passed does not include Domain Name and DomainName was not passed' {
                It 'should return correct FQDN' {
                    $Splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test'
                    }
                    Get-FQDNMemberName @Splat | Should Be 'test'
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
