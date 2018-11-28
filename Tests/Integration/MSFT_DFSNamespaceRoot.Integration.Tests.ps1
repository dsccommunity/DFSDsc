$script:DSCModuleName   = 'DFSDsc'
$script:DSCResourceName = 'MSFT_DFSNamespaceRoot'

#region HEADER
# Integration Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
Import-Module (Join-Path -Path $script:moduleRoot -ChildPath "$($script:DSCModuleName).psd1") -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Using try/finally to always cleanup even if something awful happens.
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

    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Integration" {
        # Create a SMB share for the Namespace
        [System.String] $RandomFileName = [System.IO.Path]::GetRandomFileName()

        [System.String] $ShareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"

        New-Item `
            -Path $ShareFolderRoot `
            -Type Directory

        New-SMBShare `
            -Name $NamespaceRootName `
            -Path $ShareFolderRoot `
            -FullAccess 'Everyone'

        #region DEFAULT TESTS
        It 'Should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Config" -OutputPath $TestDrive
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should -Not -Throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }
        #endregion

        It 'Should have set the resource and all the folder parameters should match' {
            # Get the Rule details
            $NamespaceRootNew = Get-DfsnRoot -Path $NamespaceRoot.Path
            $NamespaceRootNew.Path                          | Should -Be $NamespaceRoot.Path
            $NamespaceRootNew.Type                          | Should -Be $NamespaceRoot.Type
            $NamespaceRootNew.TimeToLiveSec                 | Should -Be $NamespaceRoot.TimeToLiveSec
            $NamespaceRootNew.State                         | Should -Be 'Online'
            $NamespaceRootNew.Description                   | Should -Be $NamespaceRoot.Description
            $NamespaceRootNew.NamespacePath                 | Should -Be $NamespaceRoot.Path
            $NamespaceRootNew.Flags                         | Should -Be @('Target Failback','Site Costing','Insite Referrals','AccessBased Enumeration')
        }

        It 'Should have set the resource and all the folder target parameters should match' {
            $NamespaceRootTargetNew = Get-DfsnRootTarget -Path $NamespaceRoot.Path -TargetPath $NamespaceRoot.TargetPath
            $NamespaceRootTargetNew.Path                    | Should -Be $NamespaceRoot.Path
            $NamespaceRootTargetNew.NamespacePath           | Should -Be $NamespaceRoot.Path
            $NamespaceRootTargetNew.TargetPath              | Should -Be $NamespaceRoot.TargetPath
            $NamespaceRootTargetNew.ReferralPriorityClass   | Should -Be $NamespaceRoot.ReferralPriorityClass
            $NamespaceRootTargetNew.ReferralPriorityRank    | Should -Be $NamespaceRoot.ReferralPriorityRank
        }

        # Clean up
        Remove-DFSNRoot `
            -Path $NamespaceRoot.Path `
            -Force `
            -Confirm:$false

        Remove-SMBShare `
            -Name $NamespaceRootName `
            -Confirm:$false

        Remove-Item `
            -Path $ShareFolderRoot `
            -Recurse `
            -Force
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
