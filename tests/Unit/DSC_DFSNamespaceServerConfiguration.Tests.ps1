[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSNamespaceServerConfiguration'

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
        $namespaceServerConfiguration = [PSObject]@{
            LdapTimeoutSec               = 45
            SyncIntervalSec              = 5000
            UseFQDN                      = $True
        }

        $namespaceServerConfigurationSplat = [PSObject]@{
            IsSingleInstance             = 'Yes'
            LdapTimeoutSec               = $namespaceServerConfiguration.LdapTimeoutSec
            SyncIntervalSec              = $namespaceServerConfiguration.SyncIntervalSec
            UseFQDN                      = $namespaceServerConfiguration.UseFQDN
        }

        Describe 'DSC_DFSNamespaceServerConfiguration\Get-TargetResource' {
            Context 'Namespace Server Configuration Exists' {
                Mock Get-DFSNServerConfiguration -MockWith { $namespaceServerConfiguration }

                It 'Should return correct namespace server configuration values' {
                    $result = Get-TargetResource -IsSingleInstance 'Yes'
                    $result.LdapTimeoutSec            | Should -Be $namespaceServerConfiguration.LdapTimeoutSec
                    $result.SyncIntervalSec           | Should -Be $namespaceServerConfiguration.SyncIntervalSec
                    $result.UseFQDN                   | Should -Be $namespaceServerConfiguration.UseFQDN
                }

                It 'Should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSNamespaceServerConfiguration\Set-TargetResource' {
            Mock Get-DFSNServerConfiguration -MockWith { $namespaceServerConfiguration }
            Mock Set-DFSNServerConfiguration

            Context 'Namespace Server Configuration all parameters are the same' {
                It 'Should not throw error' {
                    {
                        $splat = $namespaceServerConfigurationSplat.Clone()
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly -Times 0
                }
            }

            Context 'Namespace Server Configuration LdapTimeoutSec is different' {
                It 'Should not throw error' {
                    {
                        $splat = $namespaceServerConfigurationSplat.Clone()
                        $splat.LdapTimeoutSec = $splat.LdapTimeoutSec + 1
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly -Times 1
                }
            }

            Context 'Namespace Server Configuration SyncIntervalSec is different' {
                It 'Should not throw error' {
                    {
                        $splat = $namespaceServerConfigurationSplat.Clone()
                        $splat.SyncIntervalSec = $splat.SyncIntervalSec + 1
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly -Times 1
                }
            }

            Context 'Namespace Server Configuration UseFQDN is different' {
                It 'Should not throw error' {
                    {
                        $splat = $namespaceServerConfigurationSplat.Clone()
                        $splat.UseFQDN = -not $splat.UseFQDN
                        Set-TargetResource @splat
                    } | Should -Not -Throw
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly -Times 1
                }
            }
        }

        Describe 'DSC_DFSNamespaceServerConfiguration\Test-TargetResource' {
            Mock Get-DFSNServerConfiguration -MockWith { $namespaceServerConfiguration }

            Context 'Namespace Server Configuration all parameters are the same' {
                It 'Should return true' {
                    $splat = $namespaceServerConfigurationSplat.Clone()
                    Test-TargetResource @splat | Should -BeTrue
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                }
            }

            Context 'Namespace Server Configuration LdapTimeoutSec is different' {
                It 'Should return false' {
                    $splat = $namespaceServerConfigurationSplat.Clone()
                    $splat.LdapTimeoutSec = $splat.LdapTimeoutSec + 1
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                }
            }

            Context 'Namespace Server Configuration SyncIntervalSec is different' {
                It 'Should return false' {
                    $splat = $namespaceServerConfigurationSplat.Clone()
                    $splat.SyncIntervalSec = $splat.SyncIntervalSec + 1
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                }
            }

            Context 'Namespace Server Configuration UseFQDN is different' {
                It 'Should return false' {
                    $splat = $namespaceServerConfigurationSplat.Clone()
                    $splat.UseFQDN = -not $splat.UseFQDN
                    Test-TargetResource @splat | Should -BeFalse
                }

                It 'Should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly -Times 1
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
