$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSReplicationGroupFolder'

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
            DomainName = 'CONTOSO.COM'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
        }

        $MockReplicationGroupFolder = @(
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                FolderName = $ReplicationGroup.Folders[0]
                Description = 'Description 1'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
                DfsnPath = "\\CONTOSO.COM\Namespace\$($ReplicationGroup.Folders[0])"
            },
            [PSObject]@{
                GroupName = $ReplicationGroup.GroupName
                DomainName = $ReplicationGroup.DomainName
                FolderName = $ReplicationGroup.Folders[1]
                Description = 'Description 2'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
                DfsnPath = "\\CONTOSO.COM\Namespace\$($ReplicationGroup.Folders[1])"
            }
        )

        Describe "MSFT_xDFSReplicationGroupFolder\Get-TargetResource" {

            Context 'Replication group folder does not exist' {

                Mock Get-DfsReplicatedFolder

                It 'should throw RegGroupFolderMissingError error' {
                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupFolderMissingError) -f $MockReplicationGroupFolder[0].GroupName,$MockReplicationGroupFolder[0].FolderName)

                    {
                        $result = Get-TargetResource `
                            -GroupName $MockReplicationGroupFolder[0].GroupName `
                            -FolderName $MockReplicationGroupFolder[0].FolderName
                    } | Should Throw $errorRecord
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Requested replication group does exist' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return correct replication group' {
                    $result = Get-TargetResource `
                        -GroupName $MockReplicationGroupFolder[0].GroupName `
                        -FolderName $MockReplicationGroupFolder[0].FolderName
                    $result.GroupName | Should Be $MockReplicationGroupFolder[0].GroupName
                    $result.FolderName | Should Be $MockReplicationGroupFolder[0].FolderName
                    $result.Description | Should Be $MockReplicationGroupFolder[0].Description
                    $result.DomainName | Should Be $MockReplicationGroupFolder[0].DomainName
                    # Tests disabled until this issue is resolved:
                    # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    # $result.FileNameToExclude | Should Be $MockReplicationGroupFolder[0].FileNameToExclude
                    # $result.DirectoryNameToExclude | Should Be $MockReplicationGroupFolder[0].DirectoryNameToExclude
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSReplicationGroupFolder\Set-TargetResource" {

            Context 'Replication group folder exists but has different Description' {

                Mock Set-DfsReplicatedFolder

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.Description = 'Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different FileNameToExclude' {

                Mock Set-DfsReplicatedFolder

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.FileNameToExclude = @('*.tmp')
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different DirectoryNameToExclude' {

                Mock Set-DfsReplicatedFolder

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.DirectoryNameToExclude = @('*.tmp')
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different DfsnPath' {

                Mock Set-DfsReplicatedFolder

                It 'should not throw error' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.DfsnPath = '\\CONTOSO.COM\Public\Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsReplicatedFolder -Exactly 1
                }
            }

        }

        Describe "MSFT_xDFSReplicationGroupFolder\Test-TargetResource" {

            Context 'Replication group folder does not exist' {

                Mock Get-DfsReplicatedFolder

                It 'should throw RegGroupFolderMissingError error' {
                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.ReplicationGroupFolderMissingError) -f $MockReplicationGroupFolder[0].GroupName,$MockReplicationGroupFolder[0].FolderName)

                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists and has no differences' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return true' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different Description' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.Description = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different FileNameToExclude' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.FileNameToExclude = @('*.tmp')
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different DirectoryNameToExclude' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.DirectoryNameToExclude = @('*.tmp')
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication group folder exists but has different DfsnPath' {

                Mock Get-DfsReplicatedFolder -MockWith { return @($MockReplicationGroupFolder[0]) }

                It 'should return false' {
                    $Splat = $MockReplicationGroupFolder[0].Clone()
                    $Splat.DfsnPath = '\\CONTOSO.COM\Public\Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
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
