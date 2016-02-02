$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'HWG_cDFSNamespace'

#region HEADER
[String] $moduleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))
if ( (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'))
}
else
{
    & git @('-C',(Join-Path -Path $moduleRoot -ChildPath '\DSCResource.Tests\'),'pull')
}
Import-Module (Join-Path -Path $moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $Global:DSCModuleName `
    -DSCResourceName $Global:DSCResourceName `
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
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($Global:DSCResourceName).config.ps1"
    . $ConfigFile

    Describe "$($Global:DSCResourceName)_Integration" {
        # Create a SMB share for the Namespace
        [String] $RandomFileName = [System.IO.Path]::GetRandomFileName()
        [String] $ShareFolder = Join-Path -Path $env:Temp -ChildPath "$($Global:DSCResourceName)_$RandomFileName" 
        New-Item `
            -Path $ShareFolder `
            -Type Directory
        Write-Verbose -Verbose $ShareFolder
        New-SMBShare `
            -Name $Namespace.Namespace `
            -Path $ShareFolder `
            -FullAccess 'Everyone'
            
        #region DEFAULT TESTS
        It 'Should compile without throwing' {
            {
                Invoke-Expression -Command "$($Global:DSCResourceName)_Config -OutputPath `$TestEnvironment.WorkingFolder"
                Start-DscConfiguration -Path $TestEnvironment.WorkingFolder -ComputerName localhost -Wait -Verbose -Force
            } | Should not throw
        }

        It 'should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            # Get the Rule details
            $NamespaceNew = Get-DfsnRoot -Path $NamespacePath
            $NamespaceNew.Path                          | Should Be $NamespacePath
            $NamespaceNew.Type                          | Should Be 'Standalone'
            $NamespaceNew.TimeToLiveSec                 | Should Be 300
            $NamespaceNew.State                         | Should Be 'Online'
            $NamespaceNew.Description                   | Should Be $Namespace.Description
            $NamespaceNew.NamespacePath                 | Should Be $NamespacePath
            $NamespaceNew.EnableSiteCosting             | Should Be $Namespace.EnableSiteCosting
            $NamespaceNew.EnableInsiteReferrals         | Should Be $Namespace.EnableInsiteReferrals
            $NamespaceNew.EnableAccessBasedEnumeration  | Should Be $Namespace.EnableAccessBasedEnumeration
            $NamespaceNew.EnableRootScalability         | Should Be $Namespace.EnableRootScalability
            $NamespaceNew.EnableTargetFailback          | Should Be $Namespace.EnableTargetFailback
            $NamespaceTargetNew = Get-DfsnRootTarget -Path $NamespacePath -TargetPath $TargetPath
            $NamespaceTargetNew.ReferralPriorityClass   | Should Be $Namespace.ReferralPriorityClass
            $NamespaceTargetNew.ReferralPriorityRank    | Should Be $Namespace.ReferralPriorityRank
        }
        
        # Clean up
        Remove-DFSNRootTarget `
            -Path $NamespacePath `
            -TargetPath $TargetPath `
            -Confirm:$false
        Remove-SMBShare `
            -Name $Namespace.Namespace `
            -Confirm:$false
        Remove-Item `
            -Path $ShareFolder `
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
