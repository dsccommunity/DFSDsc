<#
These integration tests can only be run on a computer that:
1. Is a member of an Active Directory domain.
2. Has access to two Windows Server 2012 or greater servers with
   the FS-DFS-Replication and RSAT-DFS-Mgmt-Con features installed.
3. An AD User account that has the required permissions that are needed
   to create a DFS Replication Group.

If the above are available then to allow these tests to be run a
MSFT_DFSReplicationGroupFolder.config.json file must be created in the same folder as
this file. The content should be a customized version of the following:
{
    "Username":  "contoso.com\\Administrator",
    "Folders":  [
                    "TestFolder1",
                    "TestFolder2"
                ],
    "Members":  [
                    "Server1",
                    "Server2"
                ],
    "ContentPaths":  [
                    "c:\\IntegrationTests\\TestFolder1",
                    "c:\\IntegrationTests\\TestFolder2"
                ],
    "Password":  "MyPassword"
}

If the above are available and configured these integration tests will run.
#>
$script:DSCModuleName   = 'DFSDsc'
$script:DSCResourceName = 'MSFT_DFSReplicationGroupConnection'

# Test to see if the config file is available.
$configFile = "$([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path))\$($script:DSCResourceName).config.json"

if (! (Test-Path -Path $configFile))
{
    return
}

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
    #region Integration Tests
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $configFile

    Describe "$($script:DSCResourceName)_Integration" {
        # Create the Replication group to work with
        New-DFSReplicationGroup `
            -GroupName $ReplicationGroupConnection.GroupName

        foreach ($Member in $ReplicationGroupConnection.Members)
        {
            Add-DFSRMember `
                -GroupName $ReplicationGroupConnection.GroupName `
                -ComputerName $Member
        }

        foreach ($Folder in $ReplicationGroupConnection.Folders)
        {
            New-DFSReplicatedFolder `
                -GroupName $ReplicationGroupConnection.GroupName `
                -FolderName $Folder
        }

        #region DEFAULT TESTS
        It 'Should compile and apply the MOF without throwing' {
            {
                $ConfigData = @{
                    AllNodes = @(
                        @{
                            NodeName = 'localhost'
                            PSDscAllowPlainTextPassword = $true
                        }
                    )
                }

                & "$($script:DSCResourceName)_Config" -OutputPath $TestDrive -ConfigurationData $ConfigData
                Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
            } | Should -Not -Throw
        }

        It 'Should be able to call Get-DscConfiguration without throwing' {
            { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should -Not -Throw
        }
        #endregion

        It 'Should have set the resource and all the parameters should match' {
            $ReplicationGroupConnectionNew = Get-DfsrConnection `
                -GroupName $ReplicationGroupConnection.GroupName `
                -SourceComputerName $ReplicationGroupConnection.SourceComputerName `
                -DestinationComputerName $ReplicationGroupConnection.DestinationComputerName `
                -ErrorAction Stop
            $ReplicationGroupConnectionNew.GroupName               | Should -Be $ReplicationGroupConnection.GroupName
            $ReplicationGroupConnectionNew.SourceComputerName      | Should -Be $ReplicationGroupConnection.SourceComputerName
            $ReplicationGroupConnectionNew.DestinationComputerName | Should -Be $ReplicationGroupConnection.DestinationComputerName
        }

        # Clean up
        Remove-DFSReplicationGroup `
            -GroupName $ReplicationGroupConnection.GroupName `
            -RemoveReplicatedFolders `
            -Force `
            -Confirm:$false
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
