$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'BMD_cDFSRepGroupMembership'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else
{
    & git @('-C',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
    -TestType Unit 
#endregion


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
    InModuleScope $Global:DSCResourceName {
    
        # Create the Mock Objects that will be used for running tests
        $RepGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            DomainName = 'CONTOSO.COM'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
        }
        $MockRepGroup = [PSObject]@{
            GroupName = $RepGroup.GroupName
            DomainName = $RepGroup.DomainName
            Description = $RepGroup.Description
        }
        $MockRepGroupMember = @(
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                ComputerName = $RepGroup.Members[0]
            },
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                ComputerName = $RepGroup.Members[1]
            }
        )
        $MockRepGroupFolder = @(
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                FolderName = $RepGroup.Folders[0]
                Description = 'Description 1'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            },
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                FolderName = $RepGroup.Folders[1]
                Description = 'Description 2'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
            }
        )
        $MockRepGroupMembership = [PSObject]@{
            GroupName = $RepGroup.GroupName
            DomainName = $RepGroup.DomainName
            FolderName = $RepGroup.Folders[0]
            ComputerName = $RepGroup.Members[0]
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
            PrimaryMember = $True
        }
    
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'Replication group folder does not exist' {
                
                Mock Get-DfsrMembership
    
                It 'should throw RegGroupFolderMissingError error' {
                    $errorId = 'RegGroupMembershipMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.RepGroupMembershipMissingError) `
                        -f $MockRepGroupMembership.GroupName,$MockRepGroupMembership.FolderName,$MockRepGroupMembership.ComputerName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
    
                    {
                        $Result = Get-TargetResource `
                            -GroupName $MockRepGroupMembership.GroupName `
                            -FolderName $MockRepGroupMembership.FolderName `
                            -ComputerName $MockRepGroupMembership.ComputerName
                    } | Should Throw $errorRecord               
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Requested replication group does exist' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                            -GroupName $MockRepGroupMembership.GroupName `
                            -FolderName $MockRepGroupMembership.FolderName `
                            -ComputerName $MockRepGroupMembership.ComputerName
                    $Result.GroupName | Should Be $MockRepGroupMembership.GroupName
                    $Result.FolderName | Should Be $MockRepGroupMembership.FolderName               
                    $Result.ComputerName | Should Be $MockRepGroupMembership.ComputerName               
                    $Result.ContentPath | Should Be $MockRepGroupMembership.ContentPath               
                    $Result.StagingPath | Should Be $MockRepGroupMembership.StagingPath               
                    $Result.ConflictAndDeletedPath | Should Be $MockRepGroupMembership.ConflictAndDeletedPath               
                    $Result.ReadOnly | Should Be $MockRepGroupMembership.ReadOnly               
                    $Result.PrimaryMember | Should Be $MockRepGroupMembership.PrimaryMember               
                    $Result.DomainName | Should Be $MockRepGroupMembership.DomainName
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource"{
    
            Context 'Replication group folder exists but has different ContentPath' {
                
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ContentPath = 'Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different StagingPath' {
                
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.StagingPath = 'Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different ReadOnly' {
                
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ReadOnly = (-not $Splat.ReadOnly)
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different Primary Member' {
                
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.PrimaryMember = (-not $Splat.PrimaryMember)
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsrMembership -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
    
            Context 'Replication group membership does not exist' {
                
                Mock Get-DfsrMembership
    
                It 'should throw RegGroupMembershipMissingError error' {
                    $errorId = 'RegGroupMembershipMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.RepGroupMembershipMissingError) -f `
                        $MockRepGroupMembership.GroupName,$MockRepGroupMembership.FolderName,$MockRepGroupMembership.ComputerName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group membership exists and has no differences' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return true' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group membership exists but has different ContentPath' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ContentPath = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group membership exists but has different StagingPath' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.StagingPath = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group membership exists but has different ReadOnly' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupMembership.Clone()
                    $Splat.Remove('ConflictAndDeletedPath')
                    $Splat.ReadOnly = (-not $Splat.ReadOnly)
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrMembership -Exactly 1
                }
            }
    
            Context 'Replication group membership exists but has different PrimaryMember' {
                
                Mock Get-DfsrMembership -MockWith { return @($MockRepGroupMembership) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupMembership.Clone()
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