$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'BMD_cDFSNamespaceRoot'

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
            Path                         = '\\contoso.com\UnitTestNamespace' 
            TargetPath                   = '\\server1\UnitTestNamespace'
            Type                         = 'DomainV2'
            Ensure                       = 'present'
            Description                  = 'Unit Test Namespace Description'
            EnableSiteCosting            = $true
            EnableInsiteReferrals        = $true
            EnableAccessBasedEnumeration = $true
            EnableRootScalability        = $true
            EnableTargetFailback         = $true
            ReferralPriorityClass        = 'Global-Low'
            ReferralPriorityRank         = 10            
        }
        $NamespaceSplat = [PSObject]@{
            Path                         = $Namespace.Path 
            TargetPath                   = $Namespace.TargetPath
            Ensure                       = $Namespace.Ensure
            Type                         = $Namespace.Type
        }
        $NamespaceRoot = [PSObject]@{
            Path                         = $Namespace.Path
            TimeToLiveSec                = 300
            State                        = 'Online'
            Flags                        = @('Site Costing','Insite Referrals','AccessBased Enumeration','Root Scalability','Target Failback')
            Type                         = 'Domain V2'
            Description                  = $Namespace.Description
            NamespacePath                = $Namespace.Path
            TimeToLive                   = 300
        }
        $NamespaceStandaloneRoot = $NamespaceRoot.Clone()
        $NamespaceStandaloneRoot.Type = 'Standalone'
        $NamespaceTarget = [PSObject]@{
            Path                         = $Namespace.Path
            State                        = 'Online'
            ReferralPriorityClass        = $Namespace.ReferralPriorityClass
            NamespacePath                = $Namespace.Path
            ReferralPriorityRank         = $Namespace.ReferralPriorityRank
            TargetPath                   = $Namespace.TargetPath
        }    

        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'Namespace does not exist' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should return absent namespace' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Ensure | Should Be 'Absent'
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }
    
            Context 'Namespace does exist but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Path                         | Should Be $Namespace.Path
                    $Result.TargetPath                   | Should Be $Namespace.TargetPath
                    $Result.Ensure                       | Should Be 'Absent'
                    $Result.Type                         | Should Be $Namespace.Type
                    $Result.TimeToLiveSec                | Should Be $NamespaceRoot.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceRoot.State
                    $Result.Description                  | Should Be $NamespaceRoot.Description
                    $Result.EnableSiteCosting            | Should Be ($NamespaceRoot.Flags -contains 'Site Costing')
                    $Result.EnableInsiteReferrals        | Should Be ($NamespaceRoot.Flags -contains 'Insite Referrals')
                    $Result.EnableAccessBasedEnumeration | Should Be ($NamespaceRoot.Flags -contains 'AccessBased Enumeration')
                    $Result.EnableRootScalability        | Should Be ($NamespaceRoot.Flags -contains 'Root Scalability')
                    $Result.EnableTargetFailback         | Should Be ($NamespaceRoot.Flags -contains 'Target Failback')
                    $Result.ReferralPriorityClass        | Should Be $null
                    $Result.ReferralPriorityRank         | Should Be $null
                    
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace and target exists' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceSplat
                    $Result.Path                         | Should Be $Namespace.Path
                    $Result.TargetPath                   | Should Be $Namespace.TargetPath
                    $Result.Ensure                       | Should Be 'Present'
                    $Result.Type                         | Should Be $Namespace.Type
                    $Result.TimeToLiveSec                | Should Be $NamespaceRoot.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceRoot.State
                    $Result.Description                  | Should Be $NamespaceRoot.Description
                    $Result.EnableSiteCosting            | Should Be ($NamespaceRoot.Flags -contains 'Site Costing')
                    $Result.EnableInsiteReferrals        | Should Be ($NamespaceRoot.Flags -contains 'Insite Referrals')
                    $Result.EnableAccessBasedEnumeration | Should Be ($NamespaceRoot.Flags -contains 'AccessBased Enumeration')
                    $Result.EnableRootScalability        | Should Be ($NamespaceRoot.Flags -contains 'Root Scalability')
                    $Result.EnableTargetFailback         | Should Be ($NamespaceRoot.Flags -contains 'Target Failback')
                    $Result.ReferralPriorityClass        | Should Be $NamespaceTarget.ReferralPriorityClass
                    $Result.ReferralPriorityRank         | Should Be $NamespaceTarget.ReferralPriorityRank
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }
        }
    
        Describe "$($Global:DSCResourceName)\Set-TargetResource" {    

            Mock New-DFSNRoot
            Mock Set-DFSNRoot
            Mock New-DfsnRootTarget
            Mock Set-DfsnRootTarget
            Mock Remove-DfsnRootTarget

            Context 'Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 1 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different Description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Description = 'A new description'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different EnableSiteCosting' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableSiteCosting = $false
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different EnableInsiteReferrals' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableInsiteReferrals = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different EnableAccessBasedEnumeration' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableAccessBasedEnumeration = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different EnableRootScalability' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableRootScalability = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different EnableTargetFailback' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.EnableTargetFailback = $False
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace and target exists and should but has different ReferralPriorityClass' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.ReferralPriorityClass = 'SiteCost-High'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }
    
            Context 'Namespace and target exists and should but has different ReferralPriorityRank' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.ReferralPriorityRank++
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 1
                }
            }

            Context 'Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {   
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Ensure = 'Absent'
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Test-TargetResource" {

            Context 'Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should return false' {
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $false
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but a different target type is specified' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should throw exception' {                        
                    $errorId = 'NamespaceTypeConversionError'
                    $errorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f 'Standalone',$Namespace.Path,$Namespace.TargetPath,'DomainV2'
                    $errorCategory = 'InvalidOperation'
                    $exception = New-Object `
                        -TypeName Microsoft.Management.Infrastructure.CimException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $Splat = $Namespace.Clone()
                    $Splat.Type = 'Standalone'
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Namespace exists and should but has a different Description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.Description = 'A new description'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different EnableSiteCosting' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableSiteCosting = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different EnableInsiteReferrals' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableInsiteReferrals = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different EnableAccessBasedEnumeration' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableAccessBasedEnumeration = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different EnableRootScalability' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableRootScalability = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different EnableTargetFailback' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.EnableTargetFailback = $False
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different ReferralPriorityClass' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.ReferralPriorityClass = 'SiteCost-Normal'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace exists and should but has a different ReferralPriorityRank' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $Namespace.Clone()
                    $Splat.ReferralPriorityRank++
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should return true' {   
                    $Splat = $Namespace.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceTarget }
    
                It 'should return false' {   
                    $Splat = $Namespace.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return true' {   
                    $Splat = $Namespace.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-Root" {

            Context 'DFSN Root does not exist' {
                   
                $errorId = 'Cannot get DFS root properites on "{0}"' -f $NamespaceRoot.Path
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DfsnRoot { throw $errorRecord }
                
                It 'should return null' {

                    $Result = Get-Root `
                        -Path $NamespaceRoot.Path
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly 1
                }
            }

            Context 'DFSN Root exists' {
                   
                Mock Get-DfsnRoot -MockWith { $NamespaceRoot }
                
                It 'should return the expected root' {
                        
                    $Result = Get-Root `
                        -Path $NamespaceRoot.Path
                    $Result | Should Be $NamespaceRoot
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-RootTarget" {

            Context 'DFSN Root Target does not exist' {
                   
                $errorId = 'Cannot get DFS target properites on "{0}"' -f $NamespaceTarget.TargetPath
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DfsnRootTarget { throw $errorRecord }
                
                It 'should return null' {

                    $Result = Get-RootTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRootTarget -Exactly 1
                }
            }

            Context 'DFSN Root Target exists' {
                   
                Mock Get-DfsnRootTarget -MockWith { $NamespaceTarget }
                
                It 'should return the expected target' {
                        
                    $Result = Get-RootTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $Result | Should Be $NamespaceTarget
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRootTarget -Exactly 1
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