[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSNamespaceServerConfiguration'

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
        BeforeAll {
            # Backup the existing settings
            $script:serverConfigurationBackup = Get-DFSNServerConfiguration `
                -ComputerName $env:COMPUTERNAME

            $script:namespaceServerConfiguration = @{
                LdapTimeoutSec               = 45
                SyncIntervalSec              = 5000
                UseFQDN                      = $True
            }
        }

        It 'Should compile and apply the MOF without throwing' {
            {
                $configData = @{
                    AllNodes = @(
                        @{
                            NodeName        = 'localhost'
                            LdapTimeoutSec  = $script:namespaceServerConfiguration.LdapTimeoutSec
                            SyncIntervalSec = $script:namespaceServerConfiguration.SyncIntervalSec
                            UseFQDN         = $script:namespaceServerConfiguration.UseFQDN
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

        It 'Should have set the resource and all the parameters should match' {
            # Get the Rule details
            $namespaceServerConfigurationNew = Get-DfsnServerConfiguration -ComputerName $env:COMPUTERNAME
            $namespaceServerConfigurationNew.LdapTimeoutSec            = $script:namespaceServerConfiguration.LdapTimeoutSec
            $namespaceServerConfigurationNew.SyncIntervalSec           = $script:namespaceServerConfiguration.SyncIntervalSec
            $namespaceServerConfigurationNew.UseFQDN                   = $script:namespaceServerConfiguration.UseFQDN
        }

        AfterAll {
            if (-not $script:serverConfigurationBackup.UseFQDN)
            {
                $script:serverConfigurationBackup.UseFQDN = $false
            }

            # Clean up
            Set-DFSNServerConfiguration `
                -ComputerName $env:COMPUTERNAME `
                -LdapTimeoutSec $script:serverConfigurationBackup.LdapTimeoutSec `
                -SyncIntervalSec $script:serverConfigurationBackup.SyncIntervalSec `
                -UseFQDN $script:serverConfigurationBackup.UseFQDN
        }
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
