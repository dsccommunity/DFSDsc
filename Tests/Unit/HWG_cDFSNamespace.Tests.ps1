$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'HWG_cDFSNamespace'

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
            Namespace                    = 'UnitTestNamespace' 
            ComputerName                 = 'Server1'
            Ensure                       = 'present'
            DomainName                   = 'contoso.com' 
            Description                  = 'Unit Test Namespace Description'
            EnableSiteCosting            = $true
            EnableInsiteReferrals        = $true
            EnableAccessBasedEnumeration = $true
            EnableRootScalability        = $true
            EnableTargetFailback         = $true
            ReferralPriorityClass        = 'GlobalLow'
            ReferralPriorityRank         = 10            
        }
        $NamespaceSplat = [PSObject]@{
            Namespace                    = $Namespace.Namespace 
            ComputerName                 = $Namespace.ComputerName
            Ensure                       = $Namespace.Ensure
            DomainName                   = $Namespace.DomainName
        }
        $NamespaceRoot = [PSObject]@{
            Path                         = "\\$($Namespace.DomainName)\$($Namespace.Namespace)"
            TimeToLiveSec                = 300
            State                        = 'Online'
            Flags                        = 'Site Costing'
            Type                         = 'Domain V2'
            Description                  = $Namespace.Description
            NamespacePath                = "\\$($Namespace.DomainName)\$($Namespace.Namespace)"
            TimeToLive                   = 300
            EnableSiteCosting            = $Namespace.EnableSiteCosting
            EnableInsiteReferrals        = $Namespace.EnableInsiteReferrals
            EnableAccessBasedEnumeration = $Namespace.EnableAccessBasedEnumeration
            EnableRootScalability        = $Namespace.EnableRootScalability
            EnableTargetFailback         = $Namespace.EnableTargetFailback
        }
        $NamespaceTarget = [PSObject]@{
            Path                         = "\\$($Namespace.DomainName)\$($Namespace.Namespace)"
            State                        = 'Online'
            ReferralPriorityClass        = $Namespace.ReferralPriorityClass
            NamespacePath                = "\\$($Namespace.DomainName)\$($Namespace.Namespace)"
            ReferralPriorityRank         = $Namespace.ReferralPriorityRank
            TargetPath                   = "\\$($Namespace.ComputerName)\$($Namespace.Namespace)"
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
                    $Result.Ensure                       | Should Be 'Absent'
                    $Result.Path                         | Should Be $NamespaceRoot.Path
                    $Result.Type                         | Should Be $NamespaceRoot.Type
                    $Result.TimeToLiveSec                | Should Be $NamespaceRoot.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceRoot.State
                    $Result.Description                  | Should Be $NamespaceRoot.Description
                    $Result.EnableSiteCosting            | Should Be $NamespaceRoot.EnableSiteCosting
                    $Result.EnableInsiteReferrals        | Should Be $NamespaceRoot.EnableInsiteReferrals
                    $Result.EnableAccessBasedEnumeration | Should Be $NamespaceRoot.EnableAccessBasedEnumeration
                    $Result.EnableRootScalability        | Should Be $NamespaceRoot.EnableRootScalability
                    $Result.EnableTargetFailback         | Should Be $NamespaceRoot.EnableTargetFailback
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
                    $Result.Ensure                       | Should Be 'Present'
                    $Result.Path                         | Should Be $NamespaceRoot.Path
                    $Result.Type                         | Should Be $NamespaceRoot.Type
                    $Result.TimeToLiveSec                | Should Be $NamespaceRoot.TimeToLiveSec
                    $Result.State                        | Should Be $NamespaceRoot.State
                    $Result.Description                  | Should Be $NamespaceRoot.Description
                    $Result.EnableSiteCosting            | Should Be $NamespaceRoot.EnableSiteCosting
                    $Result.EnableInsiteReferrals        | Should Be $NamespaceRoot.EnableInsiteReferrals
                    $Result.EnableAccessBasedEnumeration | Should Be $NamespaceRoot.EnableAccessBasedEnumeration
                    $Result.EnableRootScalability        | Should Be $NamespaceRoot.EnableRootScalability
                    $Result.EnableTargetFailback         | Should Be $NamespaceRoot.EnableTargetFailback
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

            Mock New-DFSNRoot -ParameterFilter { $Type -eq 'DomainV2' }
            Mock New-DFSNRoot -ParameterFilter { $Type -eq 'Standalone' }
            Mock Set-DFSNRoot
            Mock New-DfsnRootTarget
            Mock Set-DfsnRootTarget
            Mock Remove-DfsnRootTarget

            Context 'Domain Namespace does not exist but should' {
                
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
                    Assert-MockCalled -commandName New-DFSNRoot -ParameterFilter { $Type -eq 'DomainV2' } -Exactly 1 
                    Assert-MockCalled -commandName New-DFSNRoot -ParameterFilter { $Type -eq 'Standalone' } -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {
                    { 
                        $Splat = $Namespace.Clone()
                        $Splat.Remove('DomainName')
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                    Assert-MockCalled -commandName New-DFSNRoot -ParameterFilter { $Type -eq 'DomainV2' } -Exactly 0 
                    Assert-MockCalled -commandName New-DFSNRoot -ParameterFilter { $Type -eq 'Standalone' } -Exactly 1 
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
                        $Splat.EnableSiteCosting = ! $Splat.EnableSiteCosting
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
                        $Splat.EnableInsiteReferrals = ! $Splat.EnableInsiteReferrals
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
                        $Splat.EnableAccessBasedEnumeration = ! $Splat.EnableAccessBasedEnumeration
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
                        $Splat.EnableRootScalability = ! $Splat.EnableRootScalability
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
                        $Splat.EnableTargetFailback = ! $Splat.EnableTargetFailback
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
                        $Splat.ReferralPriorityClass = 'GlobalHigh'
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

            Context 'Domain Namespace exists and should but standalone target is added' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should throw exception' {                        
                    $errorId = 'NamespaceTypeConversionError'
                    $errorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f $Namespace.Namespace,'NewTarget','','Standalone'
                    $errorCategory = 'InvalidOperation'
                    $exception = New-Object `
                        -TypeName Microsoft.Management.Infrastructure.CimException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $Splat = $Namespace.Clone()
                    $Splat.Remove('DomainName')
                    $Splat.ComputerName = 'NewTarget'
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace exists and should but domain target is added' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceRoot }
                Mock Get-DFSNRootTarget
    
                It 'should throw exception' {                        
                    $errorId = 'NamespaceTypeConversionError'
                    $errorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f $Namespace.Namespace,'NewTarget',$Namespace.DomainName,'Domain'
                    $errorCategory = 'InvalidOperation'
                    $exception = New-Object `
                        -TypeName Microsoft.Management.Infrastructure.CimException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $Splat = $Namespace.Clone()
                    $Splat.ComputerName = 'NewTarget'
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
                    $Splat.EnableSiteCosting = ! $Splat.EnableSiteCosting
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
                    $Splat.EnableInsiteReferrals = ! $Splat.EnableInsiteReferrals
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
                    $Splat.EnableAccessBasedEnumeration = ! $Splat.EnableAccessBasedEnumeration
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
                    $Splat.EnableRootScalability = ! $Splat.EnableRootScalability
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
                    $Splat.EnableTargetFailback = ! $Splat.EnableTargetFailback
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
                    $Splat.ReferralPriorityClass = 'GlobalHigh'
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

        Describe "$($Global:DSCResourceName)\Get-NamespacePath" {

            Context 'DFSN domain namespace parameters passed' {
                
                It 'should correct namespace path' {
                    $Result = Get-NamespacePath `
                        -Namespace $Namespace.Namespace `
                        -ComputerName $Namespace.ComputerName `
                        -DomainName $Namespace.DomainName
                    $Result | Should Be "\\$($Namespace.DomainName)\$($Namespace.Namespace)"
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-TargetPath" {

            Context 'DFSN domain target parameters passed' {
                
                It 'should return correct target path' {
                    $Result = Get-TargetPath `
                        -Namespace $Namespace.Namespace `
                        -ComputerName $Namespace.ComputerName `
                        -DomainName $Namespace.DomainName
                    $Result | Should Be "\\$($Namespace.ComputerName.ToUpper())\$($Namespace.Namespace)"
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-Root" {

            Context 'DFSN Root does not exist' {
                   
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $NamespaceRoot.Path
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
                   
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $NamespaceTarget.Path
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