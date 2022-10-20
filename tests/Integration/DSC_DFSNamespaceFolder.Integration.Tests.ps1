[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSnamespaceFolder'

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
        Context 'When creating a new folder in DFS Namespace' {
            BeforeAll {
                $script:namespaceRootName = 'IntegrationTestNamespace'
                $script:namespaceFolderName = 'TestFolder'
                $script:namespaceRoot = @{
                    Path                         = "\\$($env:COMPUTERNAME)\$script:namespaceRootName"
                    TargetPath                   = "\\$($env:COMPUTERNAME)\$script:namespaceRootName"
                }
                $script:namespaceFolder = @{
                    Path                         = "$($script:namespaceRoot.Path)\$script:namespaceFolderName"
                    TargetPath                   = "\\$($env:COMPUTERNAME)\$script:namespaceFolderName"
                    Ensure                       = 'Present'
                    TargetState                  = 'Online'
                    Description                  = 'Integration test namespace folder'
                    EnableInsiteReferrals        = $true
                    EnableTargetFailback         = $true
                    ReferralPriorityClass        = 'Global-Low'
                    ReferralPriorityRank         = 10
                }

                # Create a SMB share for the Namespace
                $randomFileName = [System.IO.Path]::GetrandomFileName()
                $script:shareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$randomFileName"

                New-Item `
                    -Path $script:shareFolderRoot `
                    -Type Directory

                New-SMBShare `
                    -Name $script:namespaceRootName `
                    -Path $script:shareFolderRoot `
                    -FullAccess 'Everyone'

                $randomFileName = [System.IO.Path]::GetrandomFileName()
                $script:shareFolderName = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$randomFileName"

                New-Item `
                    -Path $script:shareFolderName `
                    -Type Directory

                New-SMBShare `
                    -Name $script:namespaceFolderName `
                    -Path $script:shareFolderName `
                    -FullAccess 'Everyone'

                New-DFSNRoot `
                    -Path $script:namespaceRoot.Path `
                    -TargetPath $script:namespaceRoot.TargetPath `
                    -Type Standalone
            }

            It 'Should compile and apply the MOF without throwing' {
                {
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName                     = 'localhost'
                                Path                         = $script:namespaceFolder.Path
                                TargetPath                   = $script:namespaceFolder.TargetPath
                                Ensure                       = $script:namespaceFolder.Ensure
                                TargetState                  = $script:namespaceFolder.TargetState
                                Description                  = $script:namespaceFolder.Description
                                EnableInsiteReferrals        = $script:namespaceFolder.EnableInsiteReferrals
                                EnableTargetFailback         = $script:namespaceFolder.EnableTargetFailback
                                ReferralPriorityClass        = $script:namespaceFolder.ReferralPriorityClass
                                ReferralPriorityRank         = $script:namespaceFolder.ReferralPriorityRank
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
                $namespaceFolderNew = Get-DfsnFolder -Path $script:namespaceFolder.Path
                $namespaceFolderNew.Path                          | Should -Be $script:namespaceFolder.Path
                $namespaceFolderNew.TimeToLiveSec                 | Should -Be 300
                $namespaceFolderNew.State                         | Should -Be 'Online'
                $namespaceFolderNew.Description                   | Should -Be $script:namespaceFolder.Description
                $namespaceFolderNew.NamespacePath                 | Should -Be $script:namespaceFolder.Path
                $namespaceFolderNew.Flags                         | Should -Be @('Target Failback','Insite Referrals')
            }

            It 'Should have set the resource and all the folder target parameters should match' {
                $namespaceFolderTargetNew = Get-DfsnFolderTarget -Path $script:namespaceFolder.Path -TargetPath $script:namespaceFolder.TargetPath
                $namespaceFolderTargetNew.Path                    | Should -Be $script:namespaceFolder.Path
                $namespaceFolderTargetNew.NamespacePath           | Should -Be $script:namespaceFolder.Path
                $namespaceFolderTargetNew.TargetPath              | Should -Be $script:namespaceFolder.TargetPath
                $namespaceFolderTargetNew.State                   | Should -Be $script:namespaceFolder.TargetState
                $namespaceFolderTargetNew.ReferralPriorityClass   | Should -Be $script:namespaceFolder.ReferralPriorityClass
                $namespaceFolderTargetNew.ReferralPriorityRank    | Should -Be $script:namespaceFolder.ReferralPriorityRank
            }

            AfterAll {
                # Clean up
                Remove-DFSNFolder `
                    -Path $script:namespaceFolder.Path `
                    -Force `
                    -Confirm:$false

                Remove-DFSNRoot `
                    -Path $script:namespaceRoot.Path `
                    -Force `
                    -Confirm:$false

                Remove-SMBShare `
                    -Name $script:namespaceFolderName `
                    -Confirm:$false

                Remove-Item `
                    -Path $script:shareFolderName `
                    -Recurse `
                    -Force

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
