$script:DSCModuleName   = 'xDFS'
$script:DSCResourceName = 'MSFT_xDFSNamespaceFolder'

#region HEADER
# Integration Test Template Version: 1.1.0
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Using try/finally to always cleanup even if something awful happens.
try
{
    # Ensure that the tests can be performed on this computer
    $ProductType = (Get-CimInstance Win32_OperatingSystem).ProductType
    Describe 'Environment' {
        Context 'Operating System' {
            It 'Should be a Server OS' {
                $ProductType | Should Be 3
            }
        }
    }
    if ($ProductType -ne 3)
    {
        Break
    }

    $Installed = (Get-WindowsFeature -Name FS-DFS-Namespace).Installed
    Describe 'Environment' {
        Context 'Windows Features' {
            It 'Should have the DFS Namespace Feature Installed' {
                $Installed | Should Be $true
            }
        }
    }
    if ($Installed -eq $false)
    {
        Break
    }

    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Integration" {
        # Create a SMB share for the Namespace
        [String] $RandomFileName = [System.IO.Path]::GetRandomFileName()
        [String] $ShareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"
        New-Item `
            -Path $ShareFolderRoot `
            -Type Directory
        New-SMBShare `
            -Name $NamespaceRootName `
            -Path $ShareFolderRoot `
            -FullAccess 'Everyone'
        [String] $RandomFileName = [System.IO.Path]::GetRandomFileName()
        [String] $ShareFolderFolder = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"
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
        It 'Should compile without throwing' {
            {
                & "$($script:DSCResourceName)_Config" -OutputPath $TestDrive
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Rule details
            $NamespaceFolderNew = Get-DfsnFolder -Path $NamespaceFolder.Path
            $NamespaceFolderNew.Path                          | Should Be $NamespaceFolder.Path
            $NamespaceFolderNew.TimeToLiveSec                 | Should Be 300
            $NamespaceFolderNew.State                         | Should Be 'Online'
            $NamespaceFolderNew.Description                   | Should Be $NamespaceFolder.Description
            $NamespaceFolderNew.NamespacePath                 | Should Be $NamespaceFolder.Path
            $NamespaceFolderNew.Flags                         | Should Be @('Insite Referrals','Target Failback')
            $NamespaceFolderTargetNew = Get-DfsnFolderTarget -Path $NamespaceFolder.Path -TargetPath $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.Path                    | Should Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.NamespacePath           | Should Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.TargetPath              | Should Be $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.ReferralPriorityClass   | Should Be $NamespaceFolder.ReferralPriorityClass
            $NamespaceFolderTargetNew.ReferralPriorityRank    | Should Be $NamespaceFolder.ReferralPriorityRank
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
