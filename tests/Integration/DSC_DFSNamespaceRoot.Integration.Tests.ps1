[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSNamespaceRoot'

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
    -TestType 'Integration'

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '..\TestHelpers\CommonTestHelper.psm1')

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

    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$($script:dscResourceName)_Integration" {
        Context 'When creating a DFS Namespace Root' {
            BeforeAll {
                $script:namespaceRootName = 'IntegrationTestNamespace'
                $script:namespaceRoot = @{
                    Path                         = "\\$($env:COMPUTERNAME)\$script:namespaceRootName"
                    TargetPath                   = "\\$($env:COMPUTERNAME)\$script:namespaceRootName"
                    Ensure                       = 'Present'
                    Type                         = 'Standalone'
                    Description                  = 'Integration test namespace'
                    TimeToLiveSec                = 500
                    EnableSiteCosting            = $true
                    EnableInsiteReferrals        = $true
                    EnableAccessBasedEnumeration = $true
                    EnableRootScalability        = $true
                    EnableTargetFailback         = $true
                    ReferralPriorityClass        = 'Global-Low'
                    ReferralPriorityRank         = 10
                }

                # Create a SMB share for the Namespace
                $randomFileName = [System.IO.Path]::GetRandomFileName()
                $script:shareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$randomFileName"

                New-Item `
                    -Path $script:shareFolderRoot `
                    -Type Directory

                New-SMBShare `
                    -Name $script:namespaceRootName `
                    -Path $script:shareFolderRoot `
                    -FullAccess 'Everyone'
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName                     = 'localhost'
                                Path                         = $script:namespaceRoot.Path
                                TargetPath                   = $script:namespaceRoot.TargetPath
                                Ensure                       = $script:namespaceRoot.Ensure
                                Type                         = $script:namespaceRoot.Type
                                Description                  = $script:namespaceRoot.Description
                                TimeToLiveSec                = $script:namespaceRoot.TimeToLiveSec
                                EnableSiteCosting            = $script:namespaceRoot.EnableSiteCosting
                                EnableInsiteReferrals        = $script:namespaceRoot.EnableInsiteReferrals
                                EnableAccessBasedEnumeration = $script:namespaceRoot.EnableAccessBasedEnumeration
                                EnableRootScalability        = $script:namespaceRoot.EnableRootScalability
                                EnableTargetFailback         = $script:namespaceRoot.EnableTargetFailback
                                ReferralPriorityClass        = $script:namespaceRoot.ReferralPriorityClass
                                ReferralPriorityRank         = $script:namespaceRoot.ReferralPriorityRank
                            }
                        )
                    }

                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData

                    Start-DscConfiguration `
                        -Path $TestDrive `
                        -ComputerName localhost `
                        -Wait `
                        -Verbose `
                        -Force `
                        -ErrorAction Stop
                } | Should -Not -Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
            }

            It 'Should have set the resource and all the folder parameters should match' {
                # Get the Rule details
                $namespaceRootNew = Get-DfsnRoot -Path $script:namespaceRoot.Path
                $namespaceRootNew.Path          | Should -Be $script:namespaceRoot.Path
                $namespaceRootNew.Type          | Should -Be $script:namespaceRoot.Type
                $namespaceRootNew.TimeToLiveSec | Should -Be $script:namespaceRoot.TimeToLiveSec
                $namespaceRootNew.State         | Should -Be 'Online'
                $namespaceRootNew.Description   | Should -Be $script:namespaceRoot.Description
                $namespaceRootNew.NamespacePath | Should -Be $script:namespaceRoot.Path
                $namespaceRootNew.Flags         | Should -Be @('Target Failback','Site Costing','Insite Referrals','AccessBased Enumeration')
            }

            It 'Should have set the resource and all the folder target parameters should match' {
                $namespaceRootTargetNew = Get-DfsnRootTarget `
                    -Path $script:namespaceRoot.Path `
                    -TargetPath $script:namespaceRoot.TargetPath
                $namespaceRootTargetNew.Path                  | Should -Be $script:namespaceRoot.Path
                $namespaceRootTargetNew.NamespacePath         | Should -Be $script:namespaceRoot.Path
                $namespaceRootTargetNew.TargetPath            | Should -Be $script:namespaceRoot.TargetPath
                $namespaceRootTargetNew.ReferralPriorityClass | Should -Be $script:namespaceRoot.ReferralPriorityClass
                $namespaceRootTargetNew.ReferralPriorityRank  | Should -Be $script:namespaceRoot.ReferralPriorityRank
            }

            AfterAll {
                # Clean up
                Remove-DFSNRoot `
                    -Path $script:namespaceRoot.Path `
                    -Force `
                    -Confirm:$false

                Remove-SMBShare `
                    -Name $script:namespaceRootName `
                    -Confirm:$false

                Remove-Item `
                    -Path $script:shareFolderRoot `
                    -Recurse `
                    -Force
            }
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
