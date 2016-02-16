data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
GettingRepGroupMessage=Getting DFS Replication Group "{0}".
RepGroupExistsMessage=DFS Replication Group "{0}" exists.
RepGroupDoesNotExistMessage=DFS Replication Group "{0}" does not exist.
SettingRegGroupMessage=Setting DFS Replication Group "{0}".
EnsureRepGroupExistsMessage=Ensuring DFS Replication Group "{0}" exists.
EnsureRepGroupDoesNotExistMessage=Ensuring DFS Replication Group "{0}" does not exist.
RepGroupCreatedMessage=DFS Replication Group "{0}" has been created.
RepGroupDescriptionUpdatedMessage=DFS Replication Group "{0}" description has been updated.
RepGroupMemberAddedMessage=DFS Replication Group "{0}" added member "{2}".
RepGroupMemberRemovedMessage=DFS Replication Group "{0}" removed member "{2}".
RepGroupFolderAddedMessage=DFS Replication Group "{0}" added folder "{2}".
RepGroupFolderRemovedMessage=DFS Replication Group "{0}" removed folder "{2}".
RepGroupContentPathUpdatedMessage=DFS Replication Group "{0}" Content Path for "{2}" updated.
RepGroupExistsRemovedMessage=DFS Replication Group "{0}" existed, but has been removed.
RepGroupFullMeshConnectionAddedMessage=DFS Replication Group "{0}" Fullmesh Connection from "{2}" to "{3}" added.
RepGroupFullMeshConnectionUpdatedMessage=DFS Replication Group "{0}" Fullmesh Connection from "{2}" to "{3}" updated.
TestingRegGroupMessage=Testing DFS Replication Group "{0}".
RepGroupDescriptionNeedsUpdateMessage=DFS Replication Group "{0}" description is different. Change required.
RepGroupMembersNeedUpdateMessage=DFS Replication Group "{0}" members are different. Change required.
RepGroupFoldersNeedUpdateMessage=DFS Replication Group "{0}" folders are different. Change required.
RepGroupContentPathNeedUpdateMessage=DFS Replication Group "{0}" Content Path for "{2}" is different. Change required.
RepGroupDoesNotExistButShouldMessage=DFS Replication Group "{0}" does not exist but should. Change required.
RepGroupExistsButShouldNotMessage=DFS Replication Group "{0}" exists but should not. Change required.
RepGroupDoesNotExistAndShouldNotMessage=DFS Replication Group "{0}" does not exist and should not. Change not required.
RepGroupFullMeshMissingConnectionMessage=DFS Replication Group "{0}" Fullmesh Connection from "{2}" to "{3}" does not exist. Change required.
RepGroupFullMeshDisabledConnectionMessage=DFS Replication Group "{0}" Fullmesh Connection from "{2}" to "{3}" is disabled. Change required.
RepGroupDomainMismatchError=DFS Replication Group "{0}" Domain name in Member "{1}" does not match DomainName "{2}". Configuration correction required.
'@
}


function Get-TargetResource
{
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $DomainName
    )
    
    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingRepGroupMessage) `
            -f $GroupName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    $returnValue = $splat.Clone()
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DfsReplicationGroup @Splat `
        -ErrorAction Stop
    if ($RepGroup)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupExistsMessage) `
                -f $GroupName,$DomainName
            ) -join '' )
          
        # Array paramters are disabled until this issue is resolved:
        # https://windowsserver.uservoice.com/forums/301869-powershell/suggestions/11088807-get-dscconfiguration-fails-with-embedded-cim-type
        $returnValue += @{
            Ensure = 'Present'
            Description = $RepGroup.Description
            DomainName = $RepGroup.DomainName
            # Members = @((Get-DfsrMember @Splat -ErrorAction Stop).ComputerName)
            # Folders = @((Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName)
            # ContentPaths = @()
        }
    }
    else
    {       
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupDoesNotExistMessage) `
                -f $GroupName,$DomainName
            ) -join '' )
        $returnValue += @{ Ensure = 'Absent' }
    }

    $returnValue
} # Get-TargetResource


function Set-TargetResource
{
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [String[]]
        $Members,

        [String[]]
        $Folders,

        [ValidateSet('Fullmesh','Manual')]
        [String]
        $Topology = 'Manual',

        [String[]]
        $ContentPaths,

        [String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupMessage) `
            -f $GroupName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DfsReplicationGroup @Splat `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The rep group should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupExistsMessage) `
                -f $GroupName,$DomainName
            ) -join '' )

        if ($Description)
        {
            $Splat += @{ Description = $Description }
        } # if

        if ($RepGroup)
        {
            # The RG exists already - Check the existing RG and members
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )
            # Check the description
            if (($Description) -and ($RepGroup.Description -ne $Description))
            {
                Set-DfsReplicationGroup @Splat -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupDescriptionUpdatedMessage) `
                        -f $GroupName,$DomainName
                    ) -join '' )
            } # if
        }
        else
        {
            # Ths Rep Groups doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupDoesNotExistMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )
            New-DfsReplicationGroup @Splat -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupCreatedMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )

        } # if

        # Clean up the splat so we can use it in the next cmdlets
        $Splat.Remove('Description')
        
        # Create an array of FQDN Members from the Members Array
        $Splat += @{ ComputerName = '' }
        foreach ($Member in $Members)
        {
            $Splat.ComputerName = $Member
            $FQDNMembers += @( Get-FQDNMemberName @Splat )
        }
        $Splat.Remove('ComputerName')
        
        # Get the existing members of this DFS Rep Group
        $ExistingMembers = (Get-DfsrMember @Splat -ErrorAction Stop).DnsName

        # Add any missing members
        foreach ($Member in $FQDNMembers) 
        {
            if ($Member -notin $ExistingMembers)
            {
                # Member is missing - add it
                Add-DfsrMember @Splat `
                    -ComputerName $Member `
                    -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMemberAddedMessage) `
                        -f $GroupName,$DomainName,$Member
                    ) -join '' )
            } # if
        } # foreach

        # Remove any members that shouldn't exist
        foreach ($ExistingMember in $ExistingMembers)
        {
            if ($ExistingMember -notin $FQDNMembers)
            {
                # Member exists but shouldn't - remove it
                Remove-DfsrMember @Splat `
                    -ComputerName $ExistingMember `
                    -Force `
                    -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMemberRemovedMessage) `
                        -f $GroupName,$DomainName,$ExistingMember
                    ) -join '' )
            } # if
        } # foreach

        # Get the existing folders of this DFS Rep Group
        $ExistingFolders = (Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName

        # Add any missing folders
        foreach ($Folder in $Folders)
        {
            if ($Folder -notin $ExistingFolders)
            {
                # Folder is missing - add it
                New-DfsReplicatedFolder @Splat `
                    -FolderName $Folder `
                    -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFolderAddedMessage) `
                        -f $GroupName,$DomainName,$Folder
                    ) -join '' )
            } # if
        } # foreach

        # Remove any folders that shouldn't exist
        foreach ($ExistingFolder in $ExistingFolders)
        {
            if ($ExistingFolder -notin $Folders)
            {
                # Folder exists but shouldn't - remove it
                Remove-DfsReplicatedFolder @Splat `
                    -Folder $ExistingFolder `
                    -Force `
                    -ErrorAction Stop
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFolderRemovedMessage) `
                        -f $GroupName,$DomainName,$ExistingFolder
                    ) -join '' )
            } # if
        } # foreach

        # Set the content paths (if any were passed in the array)
        if ($ContentPaths)
        {
            # Get the current memberships for this rep group
            $memberships = Get-DfsrMembership @Splat `
                -ErrorAction Stop
            # Scan through the content paths array
            for ($i=0; $i -lt $Folders.Count; $i++)
            {
                $ContentPath = $ContentPaths[$i]
                if ($ContentPath)
                {
                     foreach ($membership in $memberships) 
                     {
                        
                        [String] $FQDNMemberName = Get-FQDNMemberName `
                            @Splat `
                            -ComputerName $membership.ComputerName
                        [Boolean] $primarymember = ($FQDNMemberName -eq $FQDNMembers[0])
                        if (($membership.FolderName -ne $Folders[$i]) `
                            -or (($membership.ContentPath -eq $ContentPath) `
                            -and ($membership.PrimaryMember -eq $primarymember)))
                        {
                            # Don't update this membership
                            continue
                        }
                        # The Content Path for this member needs to be set
                        Set-DfsrMembership @Splat `
                            -FolderName $membership.FolderName `
                            -ComputerName $membership.ComputerName `
                            -PrimaryMember $primarymember `
                            -ContentPath $ContentPath
                        Write-Verbose -Message ( @(
                            "$($MyInvocation.MyCommand): "
                            $($LocalizedData.RepGroupContentPathUpdatedMessage) `
                                -f $GroupName,$DomainName,$membership.ComputerName
                            ) -join '' )
                    } # foreach
                } # if
            } # foreach
        } # if

        # If the topology is not manual, automatically configure the connections
        switch ($Topology)
        {
            'Fullmesh'
            {
                $Splat += @{
                    SourceComputerName = ''
                    DestinationComputerName = ''
                }
                # Scan through the combination of connections
                foreach ($source in $FQDNMembers)
                {
                    foreach ($dest in $FQDNMembers)
                    {
                        if ($source -eq $dest)
                        {
                            continue
                        }
                        $Splat.SourceComputerName = $source
                        $Splat.DestinationComputerName = $dest
                        $RepGroupConnection = Get-DfsrConnection @Splat `
                            -ErrorAction Stop
                        if ($RepGroupConnection) {
                            if ($RepGroupConnection.DisableConnection) {
                                Set-DfsrConnection @Splat `
                                    -DisableConnection $false `
                                    -ErrorAction Stop
                                Write-Verbose -Message ( @(
                                    "$($MyInvocation.MyCommand): "
                                        $($LocalizedData.RepGroupFullMeshConnectionUpdatedMessage) `
                                        -f  $GroupName,$DomainName,$source,$dest
                                    ) -join '' )
                            }
                        }
                        else
                        {
                            Add-DfsrConnection @Splat `
                                -ErrorAction Stop
                            Write-Verbose -Message ( @(
                                "$($MyInvocation.MyCommand): "
                                    $($LocalizedData.RepGroupFullMeshConnectionAddedMessage) `
                                    -f  $GroupName,$DomainName,$source,$dest
                                ) -join '' )
                        } # if
                    } # foreach
                } # foreach
            }
        } # swtich
    }
    else
    {
        # The Rep Group should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupDoesNotExistMessage) `
                -f $GroupName,$DomainName
            ) -join '' )
        if ($RepGroup)
        {
            # Remove the replication group
            Remove-DfsReplicationGroup @Splat `
                -RemoveReplicatedFolders `
                -Force `
                -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsRemovedMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )
        }
    } # if
} # Set-TargetResource


function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [String[]]
        $Members,

        [String[]]
        $Folders,

        [ValidateSet('Fullmesh','Manual')]
        [String]
        $Topology = 'Manual',

        [String[]]
        $ContentPaths,

        [String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupMessage) `
            -f $GroupName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group
    $Splat = @{ GroupName = $GroupName }
    if ($DomainName)
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $RepGroup = Get-DFSReplicationGroup @Splat `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The RG should exist
        if ($RepGroup)
        {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupExistsMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )

            # Check the description
            if (($Description) -and ($RepGroup.Description -ne $Description))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupDescriptionNeedsUpdateMessage) `
                        -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            # Create an array of FQDN Members from the Members Array
            $Splat += @{ ComputerName = '' }
            foreach ($Member in $Members)
            {
                $Splat.ComputerName = $Member
                $FQDNMembers += @( Get-FQDNMemberName @Splat )
            }
            $Splat.Remove('ComputerName')

            # Compare the Members
            $ExistingMembers = @((Get-DfsrMember @Splat -ErrorAction Stop).DnsName)
            if ((Compare-Object `
                -ReferenceObject $FQDNMembers `
                -DifferenceObject $ExistingMembers).Count -ne 0)
            {
                # There is a member different of some kind.
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupMembersNeedUpdateMessage) `
                        -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false                
            }

            # Compare the Folders
            $ExistingFolders = @((Get-DfsReplicatedFolder @Splat -ErrorAction Stop).FolderName)
            if ((Compare-Object `
                -ReferenceObject $Folders `
                -DifferenceObject $ExistingFolders).Count -ne 0)
            {
                # There is a folder different of some kind.
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupFoldersNeedUpdateMessage) `
                        -f $GroupName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false             
            }

            # Get the content paths (if any were passed in the array)
            if ($ContentPaths)
            {
                # Get the current memberships for this rep group
                $memberships = Get-DfsrMembership @Splat `
                    -ErrorAction Stop
                # Scan through the content paths array
                for ($i=0; $i -lt $Folders.Count; $i++)
                {
                    $ContentPath = $ContentPaths[$i]
                    if ($ContentPath)
                    {
                        Foreach ($membership in $memberships)
                        {
                            [Boolean]$primarymember = ($membership.ComputerName -eq $Members[0])
                            if (($membership.FolderName -ne $Folders[$i]) `
                                -or (($membership.ContentPath -eq $ContentPath) `
                                -and ($membership.PrimaryMember -eq $primarymember)))
                            {
                                # This membership is in the correct state.
                                continue
                            }
                            Write-Verbose -Message ( @(
                                "$($MyInvocation.MyCommand): "
                                $($LocalizedData.RepGroupContentPathNeedUpdateMessage) `
                                    -f $GroupName,$DomainName,$membership.ComputerName
                                ) -join '' )
                            $desiredConfigurationMatch = $false
                        } # if
                    } # if
                } # foreach
            } # if

            # If the topology is not manual, check the connections are configured
            switch ($Topology)
            {
                'Fullmesh'
                {
                    $Splat += @{
                        SourceComputerName = ''
                        DestinationComputerName = ''
                    }
                    # Scan through the combination of connections
                    foreach ($source in $FQDNMembers)
                    {
                        foreach ($dest in $FQDNMembers)
                        {
                            if ($source -eq $dest)
                            {
                                continue
                            }
                            $Splat.SourceComputerName = $source
                            $Splat.DestinationComputerName = $dest
                            $RepGroupConnection = Get-DfsrConnection @Splat `
                                -ErrorAction Stop
                            if ($RepGroupConnection)
                            {
                                if ($RepGroupConnection.DisableConnection)
                                {
                                    Write-Verbose -Message ( @(
                                        "$($MyInvocation.MyCommand): "
                                         $($LocalizedData.RepGroupFullMeshDisabledConnectionMessage) `
                                            -f  $GroupName,$DomainName,$source,$dest
                                        ) -join '' )
                                    $desiredConfigurationMatch = $false
                                }
                            }
                            else
                            {
                                Write-Verbose -Message ( @(
                                    "$($MyInvocation.MyCommand): "
                                     $($LocalizedData.RepGroupFullMeshMissingConnectionMessage) `
                                        -f  $GroupName,$DomainName,$source,$dest
                                    ) -join '' )
                                $desiredConfigurationMatch = $false
                            }
                        }
                    }
                }
            }
        }
        else
        {
            # Ths RG doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupDoesNotExistButShouldMessage) `
                    -f  $GroupName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The RG should not exist
        if ($RepGroup)
        {
            # The RG exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupExistsButShouldNotMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        else
        {
            # The RG does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupDoesNotExistAndShouldNotMessage) `
                    -f $GroupName,$DomainName
                ) -join '' )
        }
    } # if
    return $desiredConfigurationMatch
} # Test-TargetResource


# Helper functions
<#
.SYNOPSIS
    Returns the FQDN Member name based on the ComputerName and DomainName that are provided.
    
    If the ComputerName is already an FQDN but the domain in the FQDN does not match the
    value passed in DomainName then throw an exception.
    
    If the ComputerName is already an FQDN and the domain in the FQDN does match the value
    passed in DomainName then the existing ComputerName is returned.
    
    If the ComputerName is not already an FQDN and the DomainName passed is not empty then
    the ComputerName and DomainName are combined and returned.
    
    If the ComputerName is not already an FQDN and the DomainName passed is empty then
    the ComputerName is returned.
#>
function Get-FQDNMemberName
{
    [OutputType([System.String])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $GroupName,

        [parameter(Mandatory = $true)]
        [String]
        $ComputerName,

        [String]
        $DomainName
    )
    
    if ($ComputerName.Contains('.'))
    {
        if (($DomainName -ne $null) -and ($DomainName -ne ''))
        {
            if ($ComputerName -like "*.$DomainName")
            {
                return $ComputerName.ToLower()
            }
            else
            {
                $ExceptionParameters = @{
                    errorId = 'RepGroupDomainMismatchError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.RepGroupDomainMismatchError `
                        -f $GroupName,$ComputerName,$DomainName)
                }
                New-LabException @ExceptionParameters
            }
        }
        else
        {
            Return $ComputerName.ToLower()
        }
    }
    else
    {
        if (($DomainName -ne $null) -and ($DomainName -ne ''))
        {
            Return $ComputerName.ToLower()
        }
        else
        {
            Return "$ComputerName.$DomainName".ToLower()          
        }        
    }

} # Get-FQDNMemberName

<#
.SYNOPSIS
    Throw a custom exception.
#>
function New-Exception
{
    [CmdLetBinding()]
    param
    (
        [Parameter(Mandatory)]
        [String] $errorId,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $errorCategory,

        [Parameter(Mandatory)]
        [String] $errorMessage
    )

    $exception = New-Object -TypeName System.Exception `
        -ArgumentList $errorMessage
    $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null

    throw $errorRecord
} # New-Exception

Export-ModuleMember -Function *-TargetResource