$Global:DSCModuleName   = 'cDFS'
$Global:DSCResourceName = 'BMD_cDFSNamespaceRoot'

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
        [String] $ShareFolderRoot = Join-Path -Path $env:Temp -ChildPath "$($Global:DSCResourceName)_$RandomFileName" 
        New-Item `
            -Path $ShareFolderRoot `
            -Type Directory
        New-SMBShare `
            -Name $NamespaceRootName `
            -Path $ShareFolderRoot `
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
            $NamespaceRootNew = Get-DfsnRoot -Path $NamespaceRoot.Path
            $NamespaceRootNew.Path                          | Should Be $NamespaceRoot.Path
            $NamespaceRootNew.Type                          | Should Be $NamespaceRoot.Type
            $NamespaceRootNew.TimeToLiveSec                 | Should Be $NamespaceRoot.TimeToLiveSec
            $NamespaceRootNew.State                         | Should Be 'Online'
            $NamespaceRootNew.Description                   | Should Be $NamespaceRoot.Description
            $NamespaceRootNew.NamespacePath                 | Should Be $NamespaceRoot.Path
            $NamespaceRootNew.Flags                         | Should Be @('Site Costing','Insite Referrals','AccessBased Enumeration','Target Failback')
            $NamespaceRootTargetNew = Get-DfsnRootTarget -Path $NamespaceRoot.Path -TargetPath $NamespaceRoot.TargetPath
            $NamespaceRootTargetNew.Path                    | Should Be $NamespaceRoot.Path
            $NamespaceRootTargetNew.NamespacePath           | Should Be $NamespaceRoot.Path
            $NamespaceRootTargetNew.TargetPath              | Should Be $NamespaceRoot.TargetPath
            $NamespaceRootTargetNew.ReferralPriorityClass   | Should Be $NamespaceRoot.ReferralPriorityClass
            $NamespaceRootTargetNew.ReferralPriorityRank    | Should Be $NamespaceRoot.ReferralPriorityRank
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
