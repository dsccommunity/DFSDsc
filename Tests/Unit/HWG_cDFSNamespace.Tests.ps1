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
        $NamespaceDomain = [PSObject]@{
            Namespace             = 'NamespaceDomain' 
            ComputerName          = 'Server1'
            Ensure                = 'present'
            DomainName            = 'contoso.com' 
            Description           = 'Namespace Domain Description'
        }
        $NamespaceDomainSplat = [PSObject]@{
            Namespace             = $NamespaceDomain.Namespace 
            ComputerName          = $NamespaceDomain.ComputerName
            Ensure                = $NamespaceDomain.Ensure
            DomainName            = $NamespaceDomain.DomainName
        }
        $NamespaceDomainRoot = [PSObject]@{
            Path                  = "\\$($NamespaceDomain.DomainName)\$($NamespaceDomain.Namespace)"
            TimeToLiveSec         = 300
            State                 = 'Online'
            Flags                 = 'Site Costing'
            Type                  = 'Domain V2'
            Description           = $NamespaceDomain.Description
            NamespacePath         = "\\$($NamespaceDomain.DomainName)\$($NamespaceDomain.Namespace)"
            TimeToLive            = 300
        }
        $NamespaceDomainTarget = [PSObject]@{
            Path                  = "\\$($NamespaceDomain.DomainName)\$($NamespaceDomain.Namespace)"
            State                 = 'Online'
            ReferralPriorityClass = 'sitecost-normal'
            NamespacePath         = "\\$($NamespaceDomain.DomainName)\$($NamespaceDomain.Namespace)"
            ReferralPriorityRank  = 0
            TargetPath            = "\\$($NamespaceDomain.ComputerName)\$($NamespaceDomain.Namespace)"
        }
    
        $NamespaceStandalone = [PSObject]@{
            Namespace            = 'NamespaceStandalone' 
            ComputerName         = 'Server2'
            Ensure               = 'present'
            Description          = 'Namespace Standalone Description'
        }
        $NamespaceStandaloneSplat = [PSObject]@{
            Namespace             = $NamespaceStandalone.Namespace 
            ComputerName          = $NamespaceStandalone.ComputerName
            Ensure                = $NamespaceStandalone.Ensure
            DomainName            = $NamespaceStandalone.DomainName
        }
        $NamespaceStandaloneRoot = [PSObject]@{
            Path                 = "\\$($NamespaceStandalone.ComputerName)\$($NamespaceStandalone.Namespace)"
            TimeToLiveSec        = 300
            State                = 'Online'
            Flags                = 'Site Costing'
            Type                 = 'Standalone'
            Description          = $NamespaceStandalone.Description
            NamespacePath        = "\\$($NamespaceStandalone.ComputerName)\$($NamespaceStandalone.Namespace)"
            TimeToLive           = 300
        }
        $NamespaceStandaloneTarget = [PSObject]@{
            Path                  = "\\$($NamespaceStandalone.ComputerName)\$($NamespaceStandalone.Namespace)"
            State                 = 'Online'
            ReferralPriorityClass = 'sitecost-normal'
            NamespacePath         = "\\$($NamespaceStandalone.ComputerName)\$($NamespaceStandalone.Namespace)"
            ReferralPriorityRank  = 0
            TargetPath            = "\\$($NamespaceStandalone.ComputerName)\$($NamespaceStandalone.Namespace)"            
        }

        Describe "$($Global:DSCResourceName)\Get-TargetResource" {
    
            Context 'Namespace does not exist' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should return absent namespace' {
                    $Result = Get-TargetResource @NamespaceDomainSplat
                    $Result.Ensure | Should Be 'Absent'
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }
    
            Context 'Namespace does exist but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceDomainSplat
                    $Result.Ensure        | Should Be 'Absent'
                    $Result.Path          | Should Be $NamespaceDomainRoot.Path
                    $Result.Type          | Should Be $NamespaceDomainRoot.Type
                    $Result.TimeToLiveSec | Should Be $NamespaceDomainRoot.TimeToLiveSec
                    $Result.State         | Should Be $NamespaceDomainRoot.State
                    $Result.Description   | Should Be $NamespaceDomainRoot.Description
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Namespace and target exists' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceDomainTarget }
    
                It 'should return correct replication group' {
                    $Result = Get-TargetResource @NamespaceDomainSplat
                    $Result.Ensure        | Should Be 'Present'
                    $Result.Path          | Should Be $NamespaceDomainRoot.Path
                    $Result.Type          | Should Be $NamespaceDomainRoot.Type
                    $Result.TimeToLiveSec | Should Be $NamespaceDomainRoot.TimeToLiveSec
                    $Result.State         | Should Be $NamespaceDomainRoot.State
                    $Result.Description   | Should Be $NamespaceDomainRoot.Description
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
            Mock Remove-DfsnRootTarget

            Context 'Domain Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {
                    { 
                        $Splat = $NamespaceDomain.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {
                    { 
                        $Splat = $NamespaceStandalone.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Domain Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $NamespaceDomain.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $NamespaceStandalone.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Domain Namespace exists and should but has a different description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $NamespaceDomain.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace exists and should but has a different description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {                        
                    { 
                        $Splat = $NamespaceStandalone.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Domain Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceDomainTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceDomain.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceStandaloneTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceStandalone.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly 0 
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }
    
            Context 'Domain Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceDomainTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceDomain.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceStandaloneTarget }
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceStandalone.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 1
                }
            }

            Context 'Domain Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceDomain.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should not throw error' {   
                    { 
                        $Splat = $NamespaceStandalone.Clone()
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
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly 0
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Test-TargetResource" {

            Context 'Domain Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should return false' {
                    $Splat = $NamespaceDomain.Clone()
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace does not exist but should' {
                
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget
    
                It 'should return false' {
                    $Splat = $NamespaceStandalone.Clone()
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Domain Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $NamespaceDomain.Clone()
                    Test-TargetResource @Splat | Should Be $false
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace exists and should but target does not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $NamespaceStandalone.Clone()
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Domain Namespace exists and should but standalone target is added' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should throw exception' {                        
                    $errorId = 'NamespaceTypeConversionError'
                    $errorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f $NamespaceStandalone.Namespace,$NamespaceStandalone.ComputerName,'','Standalone'
                    $errorCategory = 'InvalidOperation'
                    $exception = New-Object `
                        -TypeName Microsoft.Management.Infrastructure.CimException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $Splat = $NamespaceStandalone.Clone()
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }

            Context 'Standalone Namespace exists and should but domain target is added' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should throw exception' {                        
                    $errorId = 'NamespaceTypeConversionError'
                    $errorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f $NamespaceDomain.Namespace,$NamespaceDomain.ComputerName,$NamespaceDomain.DomainName,'Domain'
                    $errorCategory = 'InvalidOperation'
                    $exception = New-Object `
                        -TypeName Microsoft.Management.Infrastructure.CimException `
                        -ArgumentList $errorMessage
                    $errorRecord = New-Object `
                        -TypeName System.Management.Automation.ErrorRecord `
                        -ArgumentList $exception, $errorId, $errorCategory, $null

                    $Splat = $NamespaceDomain.Clone()
                    { Test-TargetResource @Splat } | Should Throw $errorRecord
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 0
                }
            }
            Context 'Domain Namespace exists and should but has a different description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $NamespaceDomain.Clone()
                    $Splat.Description = 'A new description'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace exists and should but has a different description' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return false' {                        
                    $Splat = $NamespaceStandalone.Clone()
                    $Splat.Description = 'A new description'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Domain Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceDomainTarget }
    
                It 'should return true' {   
                    $Splat = $NamespaceDomain.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace and target exists and should' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceStandaloneTarget }
    
                It 'should return true' {   
                    $Splat = $NamespaceStandalone.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Domain Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceDomainTarget }
    
                It 'should return false' {   
                    $Splat = $NamespaceDomain.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace target exists but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget -MockWith { $NamespaceStandaloneTarget }
    
                It 'should return false' {   
                    $Splat = $NamespaceStandalone.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Domain Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceDomainRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return true' {   
                    $Splat = $NamespaceDomain.Clone()
                    $Splat.Ensure = 'Absent'
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly 1
                }
            }

            Context 'Standalone Namespace target does not exist but should not' {
                
                Mock Get-DFSNRoot -MockWith { $NamespaceStandaloneRoot }
                Mock Get-DFSNRootTarget
    
                It 'should return true' {   
                    $Splat = $NamespaceStandalone.Clone()
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
                
                It 'should return null' {
                    $Result = Get-NamespacePath `
                        -Namespace $NamespaceDomain.Namespace `
                        -ComputerName $NamespaceDomain.ComputerName `
                        -DomainName $NamespaceDomain.DomainName
                    $Result | Should Be "\\$($NamespaceDomain.DomainName)\$($NamespaceDomain.Namespace)"
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-TargetPath" {

            Context 'DFSN domain target parameters passed' {
                
                It 'should return null' {
                    $Result = Get-TargetPath `
                        -Namespace $NamespaceDomain.Namespace `
                        -ComputerName $NamespaceDomain.ComputerName `
                        -DomainName $NamespaceDomain.DomainName
                    $Result | Should Be "\\$($NamespaceDomain.ComputerName.ToUpper())\$($NamespaceDomain.Namespace)"
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-Root" {

            Context 'DFSN Root does not exist' {
                   
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $NamespaceDomainRoot.Path
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
                        -Path $NamespaceDomainRoot.Path
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly 1
                }
            }

            Context 'DFSN Root exists' {
                   
                Mock Get-DfsnRoot -MockWith { $NamespaceDomainRoot }
                
                It 'should return the expected root' {
                        
                    $Result = Get-Root `
                        -Path $NamespaceDomainRoot.Path
                    $Result | Should Be $NamespaceDomainRoot
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly 1
                }
            }
        }

        Describe "$($Global:DSCResourceName)\Get-RootTarget" {

            Context 'DFSN Root Target does not exist' {
                   
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $NamespaceDomainTarget.Path
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
                        -Path $NamespaceDomainTarget.Path `
                        -TargetPath $NamespaceDomainTarget.TargetPath
                    $Result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRootTarget -Exactly 1
                }
            }

            Context 'DFSN Root Target exists' {
                   
                Mock Get-DfsnRootTarget -MockWith { $NamespaceDomainTarget }
                
                It 'should return the expected target' {
                        
                    $Result = Get-RootTarget `
                        -Path $NamespaceDomainTarget.Path `
                        -TargetPath $NamespaceDomainTarget.TargetPath
                    $Result | Should Be $NamespaceDomainTarget
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