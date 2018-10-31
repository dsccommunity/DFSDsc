$script:DSCModuleName   = 'DFSDsc'
$script:DSCResourceName = 'MSFT_DFSNamespaceRoot'

Import-Module -Name (Join-Path -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers') -ChildPath 'CommonTestHelper.psm1') -Global

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

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
            It 'Should be a Server OS' {
                $productType | Should -Be 3
            }
        }
    }

    if ($productType -ne 3)
    {
        break
    }

    $featureInstalled = (Get-WindowsFeature -Name FS-DFS-Namespace).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Namespace Feature Installed' {
                $featureInstalled | Should -Be $true
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
        $namespace = [PSObject]@{
            Path                         = '\\contoso.com\UnitTestNamespace'
            TargetPath                   = '\\server1\UnitTestNamespace'
            Type                         = 'DomainV2'
            Ensure                       = 'Present'
            Description                  = 'Unit Test Namespace Description'
            TimeToLiveSec                = 500
            EnableSiteCosting            = $true
            EnableInsiteReferrals        = $true
            EnableAccessBasedEnumeration = $true
            EnableRootScalability        = $true
            EnableTargetFailback         = $true
            ReferralPriorityClass        = 'Global-Low'
            ReferralPriorityRank         = 10
        }

        $namespaceSplat = [PSObject]@{
            Path                         = $namespace.Path
            TargetPath                   = $namespace.TargetPath
            Ensure                       = $namespace.Ensure
            Type                         = $namespace.Type
        }

        $namespaceRoot = [PSObject]@{
            Path                         = $namespace.Path
            TimeToLiveSec                = $namespace.TimeToLiveSec
            State                        = 'Online'
            Flags                        = @('Site Costing','Insite Referrals','AccessBased Enumeration','Root Scalability','Target Failback')
            Type                         = 'Domain V2'
            Description                  = $namespace.Description
            NamespacePath                = $namespace.Path
            TimeToLive                   = 500
        }

        $namespaceStandaloneRoot = $namespaceRoot.Clone()
        $namespaceStandaloneRoot.Type = 'Standalone'

        $namespaceTarget = [PSObject]@{
            Path                         = $namespace.Path
            State                        = 'Online'
            ReferralPriorityClass        = $namespace.ReferralPriorityClass
            NamespacePath                = $namespace.Path
            ReferralPriorityRank         = $namespace.ReferralPriorityRank
            TargetPath                   = $namespace.TargetPath
        }

        Describe 'MSFT_DFSNamespaceRoot\Get-TargetResource' {
            Context 'Namespace Root does not exist' {
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget

                It 'Should return absent namespace root' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Ensure | Should -Be 'Absent'
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root does exist but target does not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return correct namespace root' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Path                         | Should -Be $namespace.Path
                    $result.TargetPath                   | Should -Be $namespace.TargetPath
                    $result.Ensure                       | Should -Be 'Absent'
                    $result.Type                         | Should -Be $namespace.Type
                    $result.TimeToLiveSec                | Should -Be $namespaceRoot.TimeToLiveSec
                    $result.State                        | Should -Be $namespaceRoot.State
                    $result.Description                  | Should -Be $namespaceRoot.Description
                    $result.EnableSiteCosting            | Should -Be ($namespaceRoot.Flags -contains 'Site Costing')
                    $result.EnableInsiteReferrals        | Should -Be ($namespaceRoot.Flags -contains 'Insite Referrals')
                    $result.EnableAccessBasedEnumeration | Should -Be ($namespaceRoot.Flags -contains 'AccessBased Enumeration')
                    $result.EnableRootScalability        | Should -Be ($namespaceRoot.Flags -contains 'Root Scalability')
                    $result.EnableTargetFailback         | Should -Be ($namespaceRoot.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should -Be $null
                    $result.ReferralPriorityRank         | Should -Be $null

                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root and Target exists' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should return correct namespace root and target' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Path                         | Should -Be $namespace.Path
                    $result.TargetPath                   | Should -Be $namespace.TargetPath
                    $result.Ensure                       | Should -Be 'Present'
                    $result.Type                         | Should -Be $namespace.Type
                    $result.TimeToLiveSec                | Should -Be $namespaceRoot.TimeToLiveSec
                    $result.State                        | Should -Be $namespaceRoot.State
                    $result.Description                  | Should -Be $namespaceRoot.Description
                    $result.EnableSiteCosting            | Should -Be ($namespaceRoot.Flags -contains 'Site Costing')
                    $result.EnableInsiteReferrals        | Should -Be ($namespaceRoot.Flags -contains 'Insite Referrals')
                    $result.EnableAccessBasedEnumeration | Should -Be ($namespaceRoot.Flags -contains 'AccessBased Enumeration')
                    $result.EnableRootScalability        | Should -Be ($namespaceRoot.Flags -contains 'Root Scalability')
                    $result.EnableTargetFailback         | Should -Be ($namespaceRoot.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should -Be $namespaceTarget.ReferralPriorityClass
                    $result.ReferralPriorityRank         | Should -Be $namespaceTarget.ReferralPriorityRank
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_DFSNamespaceRoot\Set-TargetResource' {
            Mock New-DFSNRoot
            Mock Set-DFSNRoot
            Mock New-DfsnRootTarget
            Mock Set-DfsnRootTarget
            Mock Remove-DfsnRootTarget

            Context 'Namespace Root does not exist but should' {
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but Target does not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different Description' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Description = 'A new description'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different TimeToLiveSec' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.TimeToLiveSec = $splat.TimeToLiveSec + 1
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different EnableSiteCosting' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableSiteCosting = $false
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different EnableInsiteReferrals' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableInsiteReferrals = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different EnableAccessBasedEnumeration' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableAccessBasedEnumeration = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different EnableRootScalability' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableRootScalability = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different EnableTargetFailback' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableTargetFailback = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root and Target exists and should' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root and Target exists and should but has different ReferralPriorityClass' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.ReferralPriorityClass = 'SiteCost-High'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root and Target exists and should but has different ReferralPriorityRank' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.ReferralPriorityRank++
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root and Target exists but should not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists but Target does not exist and should not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNRoot -Exactly -Times 0
                    Assert-MockCalled -commandName New-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DfsnRootTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DfsnRootTarget -Exactly -Times 0
                }
            }
        }

        Describe 'MSFT_DFSNamespaceRoot\Test-TargetResource' {
            Context 'Namespace Root does not exist but should' {
                Mock Get-DFSNRoot
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but Target does not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -Be $false
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but a different Target type is specified' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should throw exception' {
                    $errorRecord = Get-InvalidOperationRecord `
                        -Message ($($LocalizedData.NamespaceRootTypeConversionError) `
                            -f 'Standalone','DomainV2')

                    $splat = $namespace.Clone()
                    $splat.Type = 'Standalone'
                    { Test-TargetResource @splat } | Should -Throw $errorRecord
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Root exists and should but has a different Description' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.Description = 'A new description'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different TimeToLiveSec' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.TimeToLiveSec = $splat.TimeToLiveSec + 1
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different EnableSiteCosting' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableSiteCosting = $False
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different EnableInsiteReferrals' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableInsiteReferrals = $False
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different EnableAccessBasedEnumeration' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableAccessBasedEnumeration = $False
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different EnableRootScalability' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableRootScalability = $False
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different EnableTargetFailback' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableTargetFailback = $False
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different ReferralPriorityClass' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.ReferralPriorityClass = 'SiteCost-Normal'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root exists and should but has a different ReferralPriorityRank' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.ReferralPriorityRank++
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Root and Target exists and should' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should return true' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Target exists but should not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -Be $False
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Target does not exist but should not' {
                Mock Get-DFSNRoot -MockWith { $namespaceRoot }
                Mock Get-DFSNRootTarget

                It 'Should return true' {
                    $splat = $namespace.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -Be $True
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNRoot -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNRootTarget -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_DFSNamespaceRoot\Get-Root' {
            Context 'DFSN Root does not exist' {
                $errorId = 'Cannot get DFS root properites on "{0}"' -f $namespaceRoot.Path
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DfsnRoot { throw $errorRecord }

                It 'Should return null' {
                    $result = Get-Root `
                        -Path $namespaceRoot.Path
                    $result | Should -Be $null
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly -Times 1
                }
            }

            Context 'DFSN Root exists' {
                Mock Get-DfsnRoot -MockWith { $namespaceRoot }

                It 'Should return the expected root' {
                    $result = Get-Root `
                        -Path $namespaceRoot.Path
                    $result | Should -Be $namespaceRoot
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRoot -Exactly -Times 1
                }
            }
        }

        Describe 'MSFT_DFSNamespaceRoot\Get-RootTarget' {
            Context 'DFSN Root Target does not exist' {
                $errorId = 'Cannot get DFS target properites on "{0}"' -f $namespaceTarget.TargetPath
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DfsnRootTarget { throw $errorRecord }

                It 'Should return null' {
                    $result = Get-RootTarget `
                        -Path $namespaceTarget.Path `
                        -TargetPath $namespaceTarget.TargetPath
                    $result | Should -Be $null
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRootTarget -Exactly -Times 1
                }
            }

            Context 'DFSN Root Target exists' {
                Mock Get-DfsnRootTarget -MockWith { $namespaceTarget }

                It 'Should return the expected target' {
                    $result = Get-RootTarget `
                        -Path $namespaceTarget.Path `
                        -TargetPath $namespaceTarget.TargetPath
                    $result | Should -Be $namespaceTarget
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DfsnRootTarget -Exactly -Times 1
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
