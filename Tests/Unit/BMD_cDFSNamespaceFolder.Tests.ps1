$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'BMD_cDFSNamespaceFolder'

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

    $Installed = (Get-WindowsFeature -Name FS-DFS-Namespace).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Namespace Feature Installed' {
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
        $Namespace = [PSObject]@{
            Path                         = '\\contoso.com\UnitTestNamespace\Folder' 
            TargetPath                   = '\\server1\UnitTestNamespace\Folder'
            Ensure                       = 'present'
            Description                  = 'Unit Test Namespace Description'
            TimeToLiveSec                = 500
            EnableInsiteReferrals        = $true
            EnableTargetFailback         = $true
            ReferralPriorityClass        = 'Global-Low'
            ReferralPriorityRank         = 10            
        }
        $NamespaceSplat = [PSObject]@{
            Path                         = $Namespace.Path 
            TargetPath                   = $Namespace.TargetPath
            Ensure                       = $Namespace.Ensure
        }
        $NamespaceFolder = [PSObject]@{
            Path                         = $Namespace.Path
            TimeToLiveSec                = $Namespace.TimeToLiveSec
            State                        = 'Online'
            Flags                        = @('Insite Referrals','Target Failback')
            Description                  = $Namespace.Description
            NamespacePath                = $Namespace.Path
            TimeToLive                   = 500
        }
        $NamespaceTarget = [PSObject]@{
            Path                         = $Namespace.Path
            State                        = 'Online'
            ReferralPriorityClass        = $Namespace.ReferralPriorityClass
            NamespacePath                = $Namespace.Path
            ReferralPriorityRank         = $Namespace.ReferralPriorityRank
            TargetPath                   = $Namespace.TargetPath
        }    

        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'Namespace Folder does not exist' {
                
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget
    
                It 'should return absent namespace' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Ensure | Should Be 'Absent'
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 0
                }
            }
    
            Context 'Namespace Folder does exist but Target does not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Path                         | Should Be $Namespace.Path
                    $Result.TargetPath                   | Should Be $Namespace.TargetPath
                    $Result.Ensure                       | Should Be 'Absent'
                    $Result.TimeToLiveSec                | Should Be $NamespaceFolder.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceFolder.State
                    $Result.Description                  | Should Be $NamespaceFolder.Description
                    $Result.EnableInsiteReferrals        | Should Be ($NamespaceFolder.Flags -contains 'Insite Referrals')
                    $Result.EnableTargetFailback         | Should Be ($NamespaceFolder.Flags -contains 'Target Failback')
                    $Result.ReferralPriorityClass        | Should Be $null
                    $Result.ReferralPriorityRank         | Should Be $null
                    
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder and Target exists' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Path                         | Should Be $Namespace.Path
                    $Result.TargetPath                   | Should Be $Namespace.TargetPath
                    $Result.Ensure                       | Should Be 'Present'
                    $Result.TimeToLiveSec                | Should Be $NamespaceFolder.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceFolder.State
                    $Result.Description                  | Should Be $NamespaceFolder.Description
                    $Result.EnableInsiteReferrals        | Should Be ($NamespaceFolder.Flags -contains 'Insite Referrals')
                    $Result.EnableTargetFailback         | Should Be ($NamespaceFolder.Flags -contains 'Target Failback')
                    $Result.ReferralPriorityClass        | Should Be $NamespaceTarget.ReferralPriorityClass
                    $Result.ReferralPriorityRank         | Should Be $NamespaceTarget.ReferralPriorityRank
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {    

            Mock New-DFSNFolder
            Mock Set-DFSNFolder
            Mock New-DFSNFolderTarget
            Mock Set-DFSNFolderTarget
            Mock Remove-DFSNFolderTarget

            Context 'Namespace Folder does not exist but should' {
                
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 1 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but Target does not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but has a different Description' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Description = 'A new description'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but has a different TimeToLiveSec' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.TimeToLiveSec = $Splat.TimeToLiveSec + 1
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableInsiteReferrals' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableInsiteReferrals = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableTargetFailback' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableTargetFailback = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder and Target exists and should' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder and Target exists and should but has different ReferralPriorityClass' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.ReferralPriorityClass = 'SiteCost-High'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }
    
            Context 'Namespace Folder and Target exists and should but has different ReferralPriorityRank' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.ReferralPriorityRank++
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder and Target exists but should not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists but target does not exist and should not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly 0
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Test-TargetResource" {

            Context 'Namespace Folder does not exist but should' {
                
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 0
                }
            }

            Context 'Namespace Folder exists and should but Target does not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $false
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different Description' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.Description = 'A new description'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different TimeToLiveSec' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.TimeToLiveSec = $Splat.TimeToLiveSec + 1
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableInsiteReferrals' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableInsiteReferrals = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableTargetFailback' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableTargetFailback = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different ReferralPriorityClass' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.ReferralPriorityClass = 'SiteCost-Normal'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists and should but has a different ReferralPriorityRank' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.ReferralPriorityRank++
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder and Target exists and should' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should return true' {   
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder and Target exists but should not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
    
                It 'should return false' {   
                    $Splat = $Namespace.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'Namespace Folder exists but Target does not exist and should not' {
                
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                Mock Get-DFSNFolderTarget
    
                It 'should return true' {   
                    $Splat = $Namespace.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-Folder" {

            Context 'DFSN Folder does not exist' {
                   
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $NamespaceFolder.Path
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DFSNFolder { throw $errorRecord }
                
                It 'should return null' {

                    $Result = Get-Folder `
                        -Path $NamespaceFolder.Path
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                }
            }

            Context 'DFSN Folder exists' {
                   
                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }
                
                It 'should return the expected folder' {
                        
                    $Result = Get-Folder `
                        -Path $NamespaceFolder.Path
                    $Result | Should Be $NamespaceFolder
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-FolderTarget" {

            Context 'DFSN Folder Target does not exist' {
                   
                $errorId = 'Cannot get DFS target properites on "{0}"' -f $NamespaceTarget.TargetPath
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DFSNFolderTarget { throw $errorRecord }
                
                It 'should return null' {

                    $Result = Get-FolderTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'DFSN Folder Target exists' {
                   
                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }
                
                It 'should return the expected target' {
                        
                    $Result = Get-FolderTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $Result | Should Be $NamespaceTarget
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\New-TerminatingError" {

            Context 'Create a TestError Exception' {
                   
                It 'should throw an TestError exception' {
                    $errorId = 'TestError'
                    $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                    $errorMessage = 'Test Error Message'
                    $exception = New-Object `
                        -TypeName System.InvalidOperationException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null
                        
                    { New-TerminatingError `
                        -ErrorId $errorId `
                        -ErrorMessage $errorMessage `
                        -ErrorCategory $errorCategory } | Should Throw $errorRecord
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