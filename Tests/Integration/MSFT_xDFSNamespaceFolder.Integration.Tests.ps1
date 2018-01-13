$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSNamespaceFolder'

#region HEADER
# Integration Test Template Version: 1.1.0
[System.String] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xDFS'

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
            It 'should be a Server OS' {
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
            It 'should have the DFS Namespace Feature Installed' {
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

        [System.String] $RandomFileName = [System.IO.Path]::GetRandomFileName()

        [System.String] $ShareFolderFolder = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"

        New-Item `
            -Path $ShareFolderFolder `
            -Type Directory

        New-SMBShare `
            -Name $NamespaceFolderName `
            -Path $ShareFolderFolder `
            -FullAccess 'Everyone'

        New-DFSNRoot `
            -Path $NamespaceRoot.Path `
            -TargetPath $NamespaceRoot.TargetPath `
            -Type Standalone

        #region DEFAULT TESTS
        It 'should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Config" -OutputPath $TestDrive
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should -Not -Throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }
        #endregion

        It 'should have set the resource and all the folder parameters should match' {
            # Get the Rule details
            $NamespaceFolderNew = Get-DfsnFolder -Path $NamespaceFolder.Path
            $NamespaceFolderNew.Path                          | Should -Be $NamespaceFolder.Path
            $NamespaceFolderNew.TimeToLiveSec                 | Should -Be 300
            $NamespaceFolderNew.State                         | Should -Be 'Online'
            $NamespaceFolderNew.Description                   | Should -Be $NamespaceFolder.Description
            $NamespaceFolderNew.NamespacePath                 | Should -Be $NamespaceFolder.Path
            $NamespaceFolderNew.Flags                         | Should -Be @('Target Failback','Insite Referrals')
        }

        It 'should have set the resource and all the folder target parameters should match' {
            $NamespaceFolderTargetNew = Get-DfsnFolderTarget -Path $NamespaceFolder.Path -TargetPath $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.Path                    | Should -Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.NamespacePath           | Should -Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.TargetPath              | Should -Be $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.ReferralPriorityClass   | Should -Be $NamespaceFolder.ReferralPriorityClass
            $NamespaceFolderTargetNew.ReferralPriorityRank    | Should -Be $NamespaceFolder.ReferralPriorityRank
        }

        # Clean up
        Remove-DFSNFolder `
            -Path $NamespaceFolder.Path `
            -Force `
            -Confirm:$false

        Remove-DFSNRoot `
            -Path $NamespaceRoot.Path `
            -Force `
            -Confirm:$false

        Remove-SMBShare `
            -Name $NamespaceFolderName `
            -Confirm:$false

        Remove-Item `
            -Path $ShareFolderFolder `
            -Recurse `
            -Force

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
