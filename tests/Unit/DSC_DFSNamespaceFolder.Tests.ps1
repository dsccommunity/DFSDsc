[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSNamespaceFolder'

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force -ErrorAction 'Stop'
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:dscModuleName `
        -DSCResourceName $script:dscResourceName `
        -ResourceType 'Mof' `
        -TestType 'Unit'

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

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
                $featureInstalled | Should -BeTrue
            }
        }
    }

    if ($featureInstalled -eq $false)
    {
        break
    }

    InModuleScope $script:dscResourceName {
        # Create the Mock Objects that will be used for running tests
        $namespace = [PSObject]@{
            Path                         = '\\contoso.com\UnitTestNamespace\Folder'
            TargetPath                   = '\\server1\UnitTestNamespace\Folder'
            Ensure                       = 'Present'
            TargetState                  = 'Online'
            Description                  = 'Unit Test Namespace Description'
            TimeToLiveSec                = 500
            EnableInsiteReferrals        = $true
            EnableTargetFailback         = $true
            ReferralPriorityClass        = 'Global-Low'
            ReferralPriorityRank         = 10
            State                        = 'Online'
        }

        $namespaceSplat = [PSObject]@{
            Path                         = $namespace.Path
            TargetPath                   = $namespace.TargetPath
            Ensure                       = $namespace.Ensure
        }

        $namespaceFolder = [PSObject]@{
            Path                         = $namespace.Path
            TimeToLiveSec                = $namespace.TimeToLiveSec
            State                        = 'Online'
            Flags                        = @('Insite Referrals','Target Failback')
            Description                  = $namespace.Description
            NamespacePath                = $namespace.Path
            TimeToLive                   = 500
        }

        $namespaceTarget = [PSObject]@{
            Path                         = $namespace.Path
            State                        = 'Online'
            ReferralPriorityClass        = $namespace.ReferralPriorityClass
            NamespacePath                = $namespace.Path
            ReferralPriorityRank         = $namespace.ReferralPriorityRank
            TargetPath                   = $namespace.TargetPath
        }

        Describe 'DSC_DFSNamespaceFolder\Get-TargetResource' {
            Context 'Namespace Folder does not exist' {
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget

                It 'Should return absent namespace' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Ensure | Should -Be 'Absent'
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder does exist but Target does not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return correct replication group' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Path                         | Should -Be $namespace.Path
                    $result.TargetPath                   | Should -Be $namespace.TargetPath
                    $result.Ensure                       | Should -Be 'Absent'
                    $result.TimeToLiveSec                | Should -Be $namespaceFolder.TimeToLiveSec
                    $result.State                        | Should -Be $namespaceFolder.State
                    $result.Description                  | Should -Be $namespaceFolder.Description
                    $result.EnableInsiteReferrals        | Should -Be ($namespaceFolder.Flags -contains 'Insite Referrals')
                    $result.EnableTargetFailback         | Should -Be ($namespaceFolder.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should -BeNullOrEmpty
                    $result.ReferralPriorityRank         | Should -BeNullOrEmpty
                    $result.TargetState                  | Should -BeNullOrEmpty
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder and Target exists' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return correct replication group' {
                    $result = Get-TargetResource @namespaceSplat
                    $result.Path                         | Should -Be $namespace.Path
                    $result.TargetPath                   | Should -Be $namespace.TargetPath
                    $result.Ensure                       | Should -Be 'Present'
                    $result.TimeToLiveSec                | Should -Be $namespaceFolder.TimeToLiveSec
                    $result.State                        | Should -Be $namespaceFolder.State
                    $result.Description                  | Should -Be $namespaceFolder.Description
                    $result.EnableInsiteReferrals        | Should -Be ($namespaceFolder.Flags -contains 'Insite Referrals')
                    $result.EnableTargetFailback         | Should -Be ($namespaceFolder.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should -Be $namespaceTarget.ReferralPriorityClass
                    $result.ReferralPriorityRank         | Should -Be $namespaceTarget.ReferralPriorityRank
                    $result.TargetState                  | Should -Be $namespaceTarget.State
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSNamespaceFolder\Set-TargetResource' {
            Mock New-DFSNFolder
            Mock Set-DFSNFolder
            Mock New-DFSNFolderTarget
            Mock Set-DFSNFolderTarget
            Mock Remove-DFSNFolderTarget

            Context 'Namespace Folder does not exist but should' {
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but Target does not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but has a different Description' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Description = 'A new description'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but has a different TimeToLiveSec' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.TimeToLiveSec = $splat.TimeToLiveSec + 1
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableInsiteReferrals' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableInsiteReferrals = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableTargetFailback' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.EnableTargetFailback = $False
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but has a different State' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.State = 'Offline'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder and Target exists and should' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder and Target exists and should but has different ReferralPriorityClass' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.ReferralPriorityClass = 'SiteCost-High'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder and Target exists and should but has different ReferralPriorityRank' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.ReferralPriorityRank++
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder and Target exists and should but has different TargetState' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.TargetState = 'Offline'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder and Target exists but should not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists but target does not exist and should not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should not throw error' {
                    {
                        $splat = $namespace.Clone()
                        $splat.Ensure = 'Absent'
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                    Assert-MockCalled -commandName New-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolder -Exactly -Times 0
                    Assert-MockCalled -commandName New-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Set-DFSNFolderTarget -Exactly -Times 0
                    Assert-MockCalled -commandName Remove-DFSNFolderTarget -Exactly -Times 0
                }
            }
        }

        Describe 'DSC_DFSNamespaceFolder\Test-TargetResource' {
            Context 'Namespace Folder does not exist but should' {
                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 0
                }
            }

            Context 'Namespace Folder exists and should but Target does not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different Description' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.Description = 'A new description'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different TimeToLiveSec' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.TimeToLiveSec = $splat.TimeToLiveSec + 1
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableInsiteReferrals' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableInsiteReferrals = $False
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different EnableTargetFailback' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.EnableTargetFailback = $False
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different ReferralPriorityClass' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.ReferralPriorityClass = 'SiteCost-Normal'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different ReferralPriorityRank' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.ReferralPriorityRank++
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different TargetState' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.TargetState = 'Offline'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists and should but has a different State' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.State = 'Offline'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder and Target exists and should' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return true' {
                    $splat = $namespace.Clone()
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder and Target exists but should not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return false' {
                    $splat = $namespace.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'Namespace Folder exists but Target does not exist and should not' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }
                Mock Get-DFSNFolderTarget

                It 'Should return true' {
                    $splat = $namespace.Clone()
                    $splat.Ensure = 'Absent'
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSNamespaceFolder\Get-Folder' {
            Context 'DFSN Folder does not exist' {
                $errorId = 'Cannot get DFS folder properites on "{0}"' -f $namespaceFolder.Path
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DFSNFolder { throw $errorRecord }

                It 'Should return null' {

                    $result = Get-Folder `
                        -Path $namespaceFolder.Path
                    $result | Should -BeNullOrEmpty
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                }
            }

            Context 'DFSN Folder exists' {
                Mock Get-DFSNFolder -MockWith { $namespaceFolder }

                It 'Should return the expected folder' {

                    $result = Get-Folder `
                        -Path $namespaceFolder.Path
                    $result | Should -Be $namespaceFolder
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSNamespaceFolder\Get-FolderTarget' {
            Context 'DFSN Folder Target does not exist' {
                $errorId = 'Cannot get DFS target properites on "{0}"' -f $namespaceTarget.TargetPath
                $errorCategory = 'NotSpecified'
                $exception = New-Object `
                    -TypeName Microsoft.Management.Infrastructure.CimException `
                    -ArgumentList $errorMessage
                $errorRecord = New-Object `
                    -TypeName System.Management.Automation.ErrorRecord `
                    -ArgumentList $exception, $errorId, $errorCategory, $null

                Mock Get-DFSNFolderTarget { throw $errorRecord }

                It 'Should return null' {

                    $result = Get-FolderTarget `
                        -Path $namespaceTarget.Path `
                        -TargetPath $namespaceTarget.TargetPath
                    $result | Should -BeNullOrEmpty
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }

            Context 'DFSN Folder Target exists' {
                Mock Get-DFSNFolderTarget -MockWith { $namespaceTarget }

                It 'Should return the expected target' {

                    $result = Get-FolderTarget `
                        -Path $namespaceTarget.Path `
                        -TargetPath $namespaceTarget.TargetPath
                    $result | Should -Be $namespaceTarget
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly -Times 1
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
