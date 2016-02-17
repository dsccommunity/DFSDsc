$Global:DSCModuleName   = 'xDFS'
$Global:DSCResourceName = 'MSFT_xDFSRepGroupConnection'

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
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }
        $RepGroupConnections = @(
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $RepGroup.Members[0]
                DestinationComputerName = $RepGroup.Members[1]
                Ensure = 'Present'
                Description = 'Connection Description'
                DisableConnection = $false
                DisableRDC = $false
                DomainName = 'CONTOSO.COM'
            },
            [PSObject]@{
                GroupName = 'Test Group'
                SourceComputerName = $RepGroup.Members[1]
                DestinationComputerName = $RepGroup.Members[0]
                Ensure = 'Present'
                Description = 'Connection Description'
                DisableConnection = $false
                DisableRDC = $false
                DomainName = 'CONTOSO.COM'
            }
        )
        $RepGroupConnectionDisabled = $RepGroupConnections[0].Clone()
        $RepGroupConnectionDisabled.DisableConnection = $True
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
                DnsName = "$($Repgroup.Members[0]).$($Repgroup.DomainName)"
            },
            [PSObject]@{
                GroupName = $RepGroup.GroupName
                DomainName = $RepGroup.DomainName
                ComputerName = $RepGroup.Members[1]
                DnsName = "$($Repgroup.Members[1]).$($Repgroup.DomainName)"
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
            ComputerName = $RepGroup.ComputerName
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
        }
        $MockRepGroupConnection = [PSObject]@{
            GroupName = $RepGroupConnections[0].GroupName
            SourceComputerName = $RepGroupConnections[0].SourceComputerName
            DestinationComputerName = $RepGroupConnections[0].DestinationComputerName
            Description = $RepGroupConnections[0].Description
            Enabled = (-not $RepGroupConnections[0].DisableConnection)
            RDCEnabled = (-not $RepGroupConnections[0].DisableRDC)
            DomainName = $RepGroupConnections[0].DomainName
        }
    
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'No replication group connections exist' {
                
                Mock Get-DfsrConnection
    
                It 'should return absent replication group connection' {
                    $Result = Get-TargetResource `
                        -GroupName $RepGroupConnections[0].GroupName `
                        -SourceComputerName $RepGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $RepGroupConnections[0].DestinationComputerName `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Absent'
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Requested replication group connection does exist' {
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                        -GroupName $RepGroupConnections[0].GroupName `
                        -SourceComputerName $RepGroupConnections[0].SourceComputerName `
                        -DestinationComputerName $RepGroupConnections[0].DestinationComputerName `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Present'
                    $Result.GroupName | Should Be $RepGroupConnections[0].GroupName
                    $Result.SourceComputerName | Should Be $RepGroupConnections[0].SourceComputerName
                    $Result.DestinationComputerName | Should Be $RepGroupConnections[0].DestinationComputerName
                    $Result.Description | Should Be $RepGroupConnections[0].Description
                    $Result.DisableConnection | Should Be $RepGroupConnections[0].DisableConnection
                    $Result.DisableRDC | Should Be $RepGroupConnections[0].DisableRDC
                    $Result.DomainName | Should Be $RepGroupConnections[0].DomainName
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Requested replication group connection does exist but ComputerNames passed as FQDN' {
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                        -GroupName $RepGroupConnections[0].GroupName `
                        -SourceComputerName "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" `
                        -DestinationComputerName "$($RepGroupConnections[0].DestinationComputerName).$($RepGroupConnections[0].DomainName)" `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Present'
                    $Result.GroupName | Should Be $RepGroupConnections[0].GroupName
                    $Result.SourceComputerName | Should Be $RepGroupConnections[0].SourceComputerName
                    $Result.DestinationComputerName | Should Be $RepGroupConnections[0].DestinationComputerName
                    $Result.Description | Should Be $RepGroupConnections[0].Description
                    $Result.DisableConnection | Should Be $RepGroupConnections[0].DisableConnection
                    $Result.DisableRDC | Should Be $RepGroupConnections[0].DisableRDC
                    $Result.DomainName | Should Be $RepGroupConnections[0].DomainName
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
    
            Context 'Replication Group connection does not exist but should' {
                
                Mock Get-DfsrConnection
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        Set-TargetResource @Splat
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
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        Set-TargetResource @Splat
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
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        $Splat.SourceComputerName = "$($Splat.SourceComputerName).$($Splat.DomainName)"
                        $Splat.DestinationComputerName = "$($Splat.DestinationComputerName).$($Splat.DomainName)" 
                        Set-TargetResource @Splat
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
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        $Splat.Description = 'Changed'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }
    
            Context 'Replication Group connection exists but has different DisableConnection' {
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        $Splat.DisableConnection = (-not $Splat.DisableConnection)
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Set-DfsrConnection -Exactly 1
                    Assert-MockCalled -commandName Add-DfsrConnection -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsrConnection -Exactly 0
                }
            }
    
            Context 'Replication Group connection exists but has different DisableRDC' {
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        $Splat.DisableRDC = (-not $Splat.DisableRDC)
                        $Splat.Description = 'Changed'
                        Set-TargetResource @Splat
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
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
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
                
                Mock Get-DfsrConnection -MockWith { return @($MockRepGroupConnection) }
                Mock Set-DfsrConnection
                Mock Add-DfsrConnection
                Mock Remove-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupConnections[0].Clone()
                        Set-TargetResource @Splat
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
    
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            Context 'Replication Group Connection does not exist but should' {
                
                Mock Get-DfsrConnection
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    Test-TargetResource @Splat | Should Be $False 
                    
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Replication Group Connection exists and there are no differences' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists and there are no differences but ComputerNames passed as FQDN' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    $Splat.SourceComputerName = "$($Splat.SourceComputerName).$($Splat.DomainName)"
                    $Splat.DestinationComputerName = "$($Splat.DestinationComputerName).$($Splat.DomainName)" 
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }

            Context 'Replication Group Connection exists but has different Description' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    $Splat.Description = 'Changed'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Replication Group Connection exists but has different DisableConnection' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    $Splat.DisableConnection = (-not $Splat.DisableConnection)
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Replication Group Connection exists but has different DisableRDC' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    $Splat.DisableRDC = (-not $Splat.DisableRDC)
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Replication Group Connection exists but should not' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return false' {
                    $Splat = $RepGroupConnections[0].Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsrConnection -Exactly 1
                }
            }
    
            Context 'Replication Group Connection exists and is correct' {
                
                Mock Get-DfsrConnection -MockWith { @($MockRepGroupConnection) }
    
                It 'should return true' {
                    $Splat = $RepGroupConnections[0].Clone()
                    Test-TargetResource @Splat | Should Be $True
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