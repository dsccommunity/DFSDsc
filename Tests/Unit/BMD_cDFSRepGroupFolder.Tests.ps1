$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'BMD_cDFSRepGroupFolder'

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
                DfsnPath = "\\CONTOSO.COM\Namespace\$($RepGroup.Folders[0])"
            },
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                FolderName = $RepGroup.Folders[1]
                Description = 'Description 2'
                FileNameToExclude = @('~*','*.bak','*.tmp')
                DirectoryNameToExclude = @()
                DfsnPath = "\\CONTOSO.COM\Namespace\$($RepGroup.Folders[1])"
            }
        )
        $MockRepGroupMembership = [PSObject]@{
            GroupName = $RepGroup.GroupName
            DomainName = $RepGroup.DomainName
            FolderName = $RepGroup.Folders[0]
            ComputerName = $RepGroup.ComputerName
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
        }
    
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'Replication group folder does not exist' {
                
                Mock Get-DfsReplicatedFolder
    
                It 'should throw RegGroupFolderMissingError error' {
                    $errorId = 'RegGroupFolderMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.RepGroupFolderMissingError) -f $MockRepGroupFolder[0].GroupName,$MockRepGroupFolder[0].FolderName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
    
                    {
                        $Result = Get-TargetResource `
                            -GroupName $MockRepGroupFolder[0].GroupName `
                            -FolderName $MockRepGroupFolder[0].FolderName
                    } | Should Throw $errorRecord               
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Requested replication group does exist' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                        -GroupName $MockRepGroupFolder[0].GroupName `
                        -FolderName $MockRepGroupFolder[0].FolderName
                    $Result.GroupName | Should Be $MockRepGroupFolder[0].GroupName
                    $Result.FolderName | Should Be $MockRepGroupFolder[0].FolderName               
                    $Result.Description | Should Be $MockRepGroupFolder[0].Description
                    $Result.DomainName | Should Be $MockRepGroupFolder[0].DomainName
                    # Tests disabled until this issue is resolved:
                    # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    # $Result.FileNameToExclude | Should Be $MockRepGroupFolder[0].FileNameToExclude
                    # $Result.DirectoryNameToExclude | Should Be $MockRepGroupFolder[0].DirectoryNameToExclude
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
    
            Context 'Replication group folder exists but has different Description' {
                
                Mock Set-DfsReplicatedFolder
    
                It 'should not throw error' {
                    $Splat = $MockRepGroupFolder[0].Clone()
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
                    $Splat = $MockRepGroupFolder[0].Clone()
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
                    $Splat = $MockRepGroupFolder[0].Clone()
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
                    $Splat = $MockRepGroupFolder[0].Clone()
                    $Splat.DfsnPath = '\\CONTOSO.COM\Public\Different'
                    { Set-TargetResource @Splat } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Set-DfsReplicatedFolder -Exactly 1
                }
            }
    
        }
    
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
    
            Context 'Replication group folder does not exist' {
                
                Mock Get-DfsReplicatedFolder
    
                It 'should throw RegGroupFolderMissingError error' {
                    $errorId = 'RegGroupFolderMissingError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
                    $errorMessage = $($LocalizedData.RepGroupFolderMissingError) -f $MockRepGroupFolder[0].GroupName,$MockRepGroupFolder[0].FolderName
                    $exception = New-Object -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
                    $Splat = $MockRepGroupFolder[0].Clone()
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication group folder exists and has no differences' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return true' {
                    $Splat = $MockRepGroupFolder[0].Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different Description' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupFolder[0].Clone()
                    $Splat.Description = 'Different'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different FileNameToExclude' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupFolder[0].Clone()
                    $Splat.FileNameToExclude = @('*.tmp')
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different DirectoryNameToExclude' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupFolder[0].Clone()
                    $Splat.DirectoryNameToExclude = @('*.tmp')
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication group folder exists but has different DfsnPath' {
                
                Mock Get-DfsReplicatedFolder -MockWith { return @($MockRepGroupFolder[0]) }
    
                It 'should return false' {
                    $Splat = $MockRepGroupFolder[0].Clone()
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
