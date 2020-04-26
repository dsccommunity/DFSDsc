[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
param ()

$script:dscModuleName = 'DFSDsc'
$script:dscResourceName = 'DSC_DFSNamespaceFolder'

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
        # Create a SMB share for the Namespace
        $RandomFileName = [System.IO.Path]::GetRandomFileName()

        $ShareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"

        New-Item `
            -Path $ShareFolderRoot `
            -Type Directory

        New-SMBShare `
            -Name $NamespaceRootName `
            -Path $ShareFolderRoot `
            -FullAccess 'Everyone'

        $RandomFileName = [System.IO.Path]::GetRandomFileName()

        $ShareFolderFolder = Join-Path -Path $env:Temp -ChildPath "$($script:DSCResourceName)_$RandomFileName"

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

        It 'Should compile and apply the MOF without throwing' {
            {
                & "$($script:DSCResourceName)_Config" `
                    -OutputPath $TestDrive

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
            $NamespaceFolderNew = Get-DfsnFolder -Path $NamespaceFolder.Path
            $NamespaceFolderNew.Path                          | Should -Be $NamespaceFolder.Path
            $NamespaceFolderNew.TimeToLiveSec                 | Should -Be 300
            $NamespaceFolderNew.State                         | Should -Be 'Online'
            $NamespaceFolderNew.Description                   | Should -Be $NamespaceFolder.Description
            $NamespaceFolderNew.NamespacePath                 | Should -Be $NamespaceFolder.Path
            $NamespaceFolderNew.Flags                         | Should -Be @('Target Failback','Insite Referrals')
        }

        It 'Should have set the resource and all the folder target parameters should match' {
            $NamespaceFolderTargetNew = Get-DfsnFolderTarget -Path $NamespaceFolder.Path -TargetPath $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.Path                    | Should -Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.NamespacePath           | Should -Be $NamespaceFolder.Path
            $NamespaceFolderTargetNew.TargetPath              | Should -Be $NamespaceFolder.TargetPath
            $NamespaceFolderTargetNew.ReferralPriorityClass   | Should -Be $NamespaceFolder.ReferralPriorityClass
            $NamespaceFolderTargetNew.ReferralPriorityRank    | Should -Be $NamespaceFolder.ReferralPriorityRank
        }

        AfterAll {
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
    }
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
