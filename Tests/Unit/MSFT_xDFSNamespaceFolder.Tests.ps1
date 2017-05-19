$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSNamespaceFolder'

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
        $Namespace = [PSObject]@{
            Path                         = '\\contoso.com\UnitTestNamespace\Folder'
            TargetPath                   = '\\server1\UnitTestNamespace\Folder'
            Ensure                       = 'Present'
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

        Describe "MSFT_xDFSNamespaceFolder\Get-TargetResource" {

            Context 'Namespace Folder does not exist' {

                Mock Get-DFSNFolder
                Mock Get-DFSNFolderTarget

                It 'should return absent namespace' {
                    $result = Get-TargetResource @NamespaceSplat
                    $result.Ensure | Should Be 'Absent'
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
                    $result = Get-TargetResource @NamespaceSplat
                    $result.Path                         | Should Be $Namespace.Path
                    $result.TargetPath                   | Should Be $Namespace.TargetPath
                    $result.Ensure                       | Should Be 'Absent'
                    $result.TimeToLiveSec                | Should Be $NamespaceFolder.TimeToLiveSec
                    $result.State                        | Should Be $NamespaceFolder.State
                    $result.Description                  | Should Be $NamespaceFolder.Description
                    $result.EnableInsiteReferrals        | Should Be ($NamespaceFolder.Flags -contains 'Insite Referrals')
                    $result.EnableTargetFailback         | Should Be ($NamespaceFolder.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should Be $null
                    $result.ReferralPriorityRank         | Should Be $null

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
                    $result = Get-TargetResource @NamespaceSplat
                    $result.Path                         | Should Be $Namespace.Path
                    $result.TargetPath                   | Should Be $Namespace.TargetPath
                    $result.Ensure                       | Should Be 'Present'
                    $result.TimeToLiveSec                | Should Be $NamespaceFolder.TimeToLiveSec
                    $result.State                        | Should Be $NamespaceFolder.State
                    $result.Description                  | Should Be $NamespaceFolder.Description
                    $result.EnableInsiteReferrals        | Should Be ($NamespaceFolder.Flags -contains 'Insite Referrals')
                    $result.EnableTargetFailback         | Should Be ($NamespaceFolder.Flags -contains 'Target Failback')
                    $result.ReferralPriorityClass        | Should Be $NamespaceTarget.ReferralPriorityClass
                    $result.ReferralPriorityRank         | Should Be $NamespaceTarget.ReferralPriorityRank
                }
                It 'should call the expected mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSNamespaceFolder\Set-TargetResource" {

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

        Describe "MSFT_xDFSNamespaceFolder\Test-TargetResource" {

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

        Describe "MSFT_xDFSNamespaceFolder\Get-Folder" {

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

                    $result = Get-Folder `
                        -Path $NamespaceFolder.Path
                    $result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                }
            }

            Context 'DFSN Folder exists' {

                Mock Get-DFSNFolder -MockWith { $NamespaceFolder }

                It 'should return the expected folder' {

                    $result = Get-Folder `
                        -Path $NamespaceFolder.Path
                    $result | Should Be $NamespaceFolder
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolder -Exactly 1
                }
            }
        }

        Describe "MSFT_xDFSNamespaceFolder\Get-FolderTarget" {

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

                    $result = Get-FolderTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $result | Should Be $null
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
                }
            }

            Context 'DFSN Folder Target exists' {

                Mock Get-DFSNFolderTarget -MockWith { $NamespaceTarget }

                It 'should return the expected target' {

                    $result = Get-FolderTarget `
                        -Path $NamespaceTarget.Path `
                        -TargetPath $NamespaceTarget.TargetPath
                    $result | Should Be $NamespaceTarget
                }
                It 'should call expected Mocks' {
                    Assert-MockCalled -commandName Get-DFSNFolderTarget -Exactly 1
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
