$Global:DSCModuleName   = 'xDFS'
$Global:DSCResourceName = 'MSFT_xDFSRepGroup'

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
        $RepGroup = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1','FileServer2')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }
        $RepGroupAllFQDN = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2.CONTOSO.COM')
            Folders = @('Folder1','Folder2')
            Topology = 'Manual'
            DomainName = 'CONTOSO.COM'
        }
        $RepGroupSomeDns = [PSObject]@{
            GroupName = 'Test Group'
            Ensure = 'Present'
            Description = 'Test Description'
            Members = @('FileServer1.CONTOSO.COM','FileServer2')
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
            ComputerName = $RepGroup.Members[0]
            ContentPath = 'd:\public\software\'
            StagingPath = 'd:\public\software\DfsrPrivate\Staging\'
            ConflictAndDeletedPath = 'd:\public\software\DfsrPrivate\ConflictAndDeleted\'
            ReadOnly = $False
            PrimaryMember = $True
        }
        $MockRepGroupMembershipNotPrimary = $MockRepGroupMembership.Clone()
        $MockRepGroupMembershipNotPrimary.PrimaryMember = $False
    
        $MockRepGroupConnection = [PSObject]@{
            GroupName = $RepGroupConnections[0].GroupName
            SourceComputerName = $RepGroupConnections[0].SourceComputerName
            DestinationComputerName = $RepGroupConnections[0].DestinationComputerName
            Description = $RepGroupConnections[0].Description
            Enabled = (-not $RepGroupConnections[0].DisableConnection)
            RDCEnabled = (-not $RepGroupConnections[0].DisableRDC)
            DomainName = $RepGroupConnections[0].DomainName
        }
        $RepGroupContentPath = $RepGroup.Clone()
        $RepGroupContentPath += @{ ContentPaths = @($MockRepGroupMembership.ContentPath) }
    
        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'No replication groups exist' {
                
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder
    
                It 'should return absent replication group' {
                    $Result = Get-TargetResource `
                        -GroupName $RepGroup.GroupName `
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
                
                Mock Get-DfsReplicationGroup -MockWith { return @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource `
                        -GroupName $RepGroup.GroupName `
                        -Ensure Present
                    $Result.Ensure | Should Be 'Present'
                    $Result.GroupName | Should Be $RepGroup.GroupName
                    $Result.Description | Should Be $RepGroup.Description
                    $Result.DomainName | Should Be $RepGroup.DomainName
                    # Tests disabled until this issue is resolved:
                    # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
                    # $Result.Members | Should Be $RepGroup.Members
                    # $Result.Folders | Should Be $RepGroup.Folders
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
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {
    
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
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupAllFQDN.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupSomeDns.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[0]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[1]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[1]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnectionDisabled) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[1]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
                Mock Add-DfsrConnection
                Mock Set-DfsrConnection
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembership) }
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupContentPath.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembership) }
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupContentPath.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock New-DfsReplicationGroup
                Mock Set-DfsReplicationGroup
                Mock Remove-DfsReplicationGroup
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Add-DfsrMember
                Mock Remove-DfsrMember
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock New-DfsReplicatedFolder
                Mock Remove-DfsReplicatedFolder
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembershipNotPrimary) }
                Mock Set-DfsrMembership
    
                It 'should not throw error' {
                    { 
                        $Splat = $RepGroupContentPath.Clone()
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
    
        Describe "$($Global:DSCResourceName)\Test-TargetResource" {
            Context 'Replication Group does not exist but should' {
                
                Mock Get-DfsReplicationGroup
                Mock Get-DfsrMember
                Mock Get-DfsReplicatedFolder
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
                    Test-TargetResource @Splat | Should Be $False
                    
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 0
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 0
                }
            }
    
            Context 'Replication Group exists but has different description' {
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroupAllFQDN.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but some Members passed as FQDN' {
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroupSomeDns.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }

            Context 'Replication Group exists but is missing a member' {
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
    
                It 'should return true' {
                    $Splat = $RepGroup.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsReplicationGroup -Exactly 1
                    Assert-MockCalled -commandName Get-DfsrMember -Exactly 1
                    Assert-MockCalled -commandName Get-DfsReplicatedFolder -Exactly 1
                }
            }
    
            Context 'Replication Group Fullmesh Topology is required and correct' {
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[0]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[1]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
    
                It 'should return true' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[0]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnectionDisabled) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[0].SourceComputerName).$($RepGroupConnections[0].DomainName)" }
                Mock Get-DfsrConnection -MockWith { @($RepGroupConnections[1]) } -ParameterFilter { $SourceComputerName -eq "$($RepGroupConnections[1].SourceComputerName).$($RepGroupConnections[1].DomainName)" }
    
                It 'should return false' {
                    $Splat = $RepGroup.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembership) }
    
                It 'should return false' {
                    $Splat = $RepGroupContentPath.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembership) }
    
                It 'should return true' {
                    $Splat = $RepGroupContentPath.Clone()
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
                
                Mock Get-DfsReplicationGroup -MockWith { @($MockRepGroup) }
                Mock Get-DfsrMember -MockWith { return $MockRepGroupMember }
                Mock Get-DfsReplicatedFolder -MockWith { return $MockRepGroupFolder }
                Mock Get-DfsrMembership -MockWith { @($MockRepGroupMembershipNotPrimary) }
    
                It 'should return false' {
                    $Splat = $RepGroupContentPath.Clone()
    
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

        Describe "$($Global:DSCResourceName)\Get-FQDNMemberName" {
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
                It 'should throw RepGroupDomainMismatchError exception' {
                    $Splat = @{
                        GroupName = 'UnitTest'
                        ComputerName = 'test.contoso.com'
                        DomainName = 'NOTMATCH.COM'
                    }
                    $ExceptionParameters = @{
                        errorId = 'RepGroupDomainMismatchError'
                        errorCategory = 'InvalidArgument'
                        errorMessage = $($LocalizedData.RepGroupDomainMismatchError `
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