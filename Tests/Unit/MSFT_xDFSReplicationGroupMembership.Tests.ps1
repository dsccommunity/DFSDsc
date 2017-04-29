$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroupMembership'

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

        # Create the Mock Objects that will be used for running tests
        $ReplicationGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            DomainName = 'CONTOSO.COM'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
        }
        $MockReplicationGroup = [PSObject]@{
            GroupName = $ReplicationGroup.GroupName
            DomainName = $ReplicationGroup.DomainName
            Description = $ReplicationGroup.Description
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
        $ReplicationGroupSomelDns = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
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

        Describe "MSFT_xDFSReplicationGroupMembership\Get-TargetResource" {

            Context 'Replication group folder does not exist' {

                Mock Get-DfsrMembership

                It 'should throw RegGroupFolderMissingError error' {
                    $errorId = 'RegGroupMembershipMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.ReplicationGroupMembershipMissingError) `
                        -f $MockReplicationGroupMembership.GroupName,$MockReplicationGroupMembership.FolderName,$MockReplicationGroupMembership.ComputerName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    {
                        $Result = Get-TargetResource `
                            -GroupName $MockReplicationGroupMembership.GroupName `
                            -FolderName $MockReplicationGroupMembership.FolderName `
                            -ComputerName $MockReplicationGroupMembership.ComputerName
                    } | Should Throw $errorRecord
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Requested replication group does exist' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                            -GroupName $MockReplicationGroupMembership.GroupName `
                            -FolderName $MockReplicationGroupMembership.FolderName `
                            -ComputerName $MockReplicationGroupMembership.ComputerName
                    $Result.GroupName | Should Be $MockReplicationGroupMembership.GroupName
                    $Result.FolderName | Should Be $MockReplicationGroupMembership.FolderName
                    $Result.ComputerName | Should Be $MockReplicationGroupMembership.ComputerName
                    $Result.ContentPath | Should Be $MockReplicationGroupMembership.ContentPath
                    $Result.StagingPath | Should Be $MockReplicationGroupMembership.StagingPath
                    $Result.ConflictAndDeletedPath | Should Be $MockReplicationGroupMembership.ConflictAndDeletedPath
                    $Result.ReadOnly | Should Be $MockReplicationGroupMembership.ReadOnly
                    $Result.PrimaryMember | Should Be $MockReplicationGroupMembership.PrimaryMember
                    $Result.DomainName | Should Be $MockReplicationGroupMembership.DomainName
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Requested replication group does exist but ComputerName passed as FQDN' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                            -GroupName $MockReplicationGroupMembership.GroupName `
                            -FolderName $MockReplicationGroupMembership.FolderName `
                            -ComputerName "$($MockReplicationGroupMembership.ComputerName).$($MockReplicationGroupMembership.DomainName)"
                    $Result.GroupName | Should Be $MockReplicationGroupMembership.GroupName
                    $Result.FolderName | Should Be $MockReplicationGroupMembership.FolderName
                    $Result.ComputerName | Should Be $MockReplicationGroupMembership.ComputerName
                    $Result.ContentPath | Should Be $MockReplicationGroupMembership.ContentPath
                    $Result.StagingPath | Should Be $MockReplicationGroupMembership.StagingPath
                    $Result.ConflictAndDeletedPath | Should Be $MockReplicationGroupMembership.ConflictAndDeletedPath
                    $Result.ReadOnly | Should Be $MockReplicationGroupMembership.ReadOnly
                    $Result.PrimaryMember | Should Be $MockReplicationGroupMembership.PrimaryMember
                    $Result.DomainName | Should Be $MockReplicationGroupMembership.DomainName
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

        }

        Describe "MSFT_xDFSReplicationGroupMembership\Set-TargetResource"{

            Context 'Replication group membership exists and has no differences' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists and has no differences but ComputerName passed as FQDN' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ComputerName = "$($Splat.ComputerName).$($Splat.DomainName)"
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ContentPath = 'Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different StagingPath' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.StagingPath = 'Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ReadOnly = (-not $Splat.ReadOnly)
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different Primary Member' {

                Mock Set-DfsrMembership

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.PrimaryMember = (-not $Splat.PrimaryMember)
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroupMembership\Test-TargetResource" {

            Context 'Replication group membership does not exist' {

                Mock Get-DfsrMembership

                It 'should throw RegGroupMembershipMissingError error' {
                    $errorId = 'RegGroupMembershipMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.ReplicationGroupMembershipMissingError) -f `
                        $MockReplicationGroupMembership.GroupName,$MockReplicationGroupMembership.FolderName,$MockReplicationGroupMembership.ComputerName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists and has no differences' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return true' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists and has no differences but ComputerName passed as FQDN' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return true' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ComputerName = "$($Splat.ComputerName).$($Splat.DomainName)"
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different ContentPath' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ContentPath = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different StagingPath' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.StagingPath = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different ReadOnly' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ReadOnly = (-not $Splat.ReadOnly)
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }

            Context 'Replication group membership exists but has different PrimaryMember' {

                Mock Get-DfsrMembership -MockWith { return @($MockReplicationGroupMembership) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.PrimaryMember = (-not $Splat.PrimaryMember)
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
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
