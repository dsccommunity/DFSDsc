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
}
finally
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}
