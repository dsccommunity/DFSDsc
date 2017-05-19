$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSNamespaceServerConfiguration'

#region HEADER
# Unit Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xDFS'
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
            It 'should be a Server OS' {
                $productType | Should Be 3
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
            It 'should have the DFS Namespace Feature Installed' {
                $featureInstalled | Should Be $true
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
        $NamespaceServerConfiguration = [PSObject]@{
            LdapTimeoutSec               = 45
            SyncIntervalSec              = 5000
            UseFQDN                      = $True
        }

        $NamespaceServerConfigurationSplat = [PSObject]@{
            IsSingleInstance             = 'Yes'
            LdapTimeoutSec               = $NamespaceServerConfiguration.LdapTimeoutSec
            SyncIntervalSec              = $NamespaceServerConfiguration.SyncIntervalSec
            UseFQDN                      = $NamespaceServerConfiguration.UseFQDN
        }

        Describe "MSFT_xDFSNamespaceServerConfiguration\Get-TargetResource" {

            Context 'Namespace Server Configuration Exists' {

                Mock Get-DFSNServerConfiguration -MockWith { $NamespaceServerConfiguration }

                It 'should return correct namespace server configuration values' {
                    $result = Get-TargetResource -IsSingleInstance 'Yes'
                    $result.LdapTimeoutSec            | Should Be $NamespaceServerConfiguration.LdapTimeoutSec
                    $result.SyncIntervalSec           | Should Be $NamespaceServerConfiguration.SyncIntervalSec
                    $result.UseFQDN                   | Should Be $NamespaceServerConfiguration.UseFQDN
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSNamespaceServerConfiguration\Set-TargetResource" {

            Mock Get-DFSNServerConfiguration -MockWith { $NamespaceServerConfiguration }
            Mock Set-DFSNServerConfiguration

            Context 'Namespace Server Configuration all parameters are the same' {
                It 'should not throw error' {
                    {
                        $Splat = $NamespaceServerConfigurationSplat.Clone()
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly 0
                }
            }

            Context 'Namespace Server Configuration LdapTimeoutSec is different' {
                It 'should not throw error' {
                    {
                        $Splat = $NamespaceServerConfigurationSplat.Clone()
                        $Splat.LdapTimeoutSec = $Splat.LdapTimeoutSec + 1
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly 1
                }
            }

            Context 'Namespace Server Configuration SyncIntervalSec is different' {
                It 'should not throw error' {
                    {
                        $Splat = $NamespaceServerConfigurationSplat.Clone()
                        $Splat.SyncIntervalSec = $Splat.SyncIntervalSec + 1
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly 1
                }
            }

            Context 'Namespace Server Configuration UseFQDN is different' {
                It 'should not throw error' {
                    {
                        $Splat = $NamespaceServerConfigurationSplat.Clone()
                        $Splat.UseFQDN = -not $Splat.UseFQDN
                        Set-TargetResource @Splat
                    } | Should Not Throw
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                    Assert-MockCalled -commandName Set-DFSNServerConfiguration -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSNamespaceServerConfiguration\Test-TargetResource" {

            Mock Get-DFSNServerConfiguration -MockWith { $NamespaceServerConfiguration }

            Context 'Namespace Server Configuration all parameters are the same' {
                It 'should return true' {
                    $Splat = $NamespaceServerConfigurationSplat.Clone()
                    Test-TargetResource @Splat | Should Be $True
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                }
            }

            Context 'Namespace Server Configuration LdapTimeoutSec is different' {
                It 'should return false' {
                    $Splat = $NamespaceServerConfigurationSplat.Clone()
                    $Splat.LdapTimeoutSec = $Splat.LdapTimeoutSec + 1
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                }
            }

            Context 'Namespace Server Configuration SyncIntervalSec is different' {
                It 'should return false' {
                    $Splat = $NamespaceServerConfigurationSplat.Clone()
                    $Splat.SyncIntervalSec = $Splat.SyncIntervalSec + 1
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
                }
            }

            Context 'Namespace Server Configuration UseFQDN is different' {
                It 'should return false' {
                    $Splat = $NamespaceServerConfigurationSplat.Clone()
                    $Splat.UseFQDN = -not $Splat.UseFQDN
                    Test-TargetResource @Splat | Should Be $False
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNServerConfiguration -Exactly 1
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
