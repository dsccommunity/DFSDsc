$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the DFSDsc.Common Module
Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
    Returns the current state of a DFS Replication Group member.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group member should exist.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group this replication
    group is in.
#>
function Get-TargetResource
{
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.GettingReplicationGroupMemberMessage) `
            -f $GroupName,$ComputerName
        ) -join '' )

    # Lookup the existing Replication Group member
    $memberParameters = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }

    $returnValue = $memberParameters.Clone()

    if ($DomainName)
    {
        $memberParameters += @{
            DomainName = $DomainName
        }
    } # if

    $replicationGroupMember = Get-DfsrMember @memberParameters `
        -ErrorAction Stop

    if ($replicationGroupMember)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMemberExistsMessage) `
                -f $GroupName,$ComputerName
            ) -join '' )

        $returnValue += @{
            Ensure = 'Present'
            Description = $replicationGroupMember.Description
            DomainName = $replicationGroupMember.DomainName
        }
    } #if
    else
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMemberDoesNotExistMessage) `
                -f $GroupName,$ComputerName
            ) -join '' )

        $returnValue += @{
            Ensure = 'Absent'
        }
    } # else

    return $returnValue
} # Get-TargetResource

<#
    .SYNOPSIS
    Sets DFS Replication Group member.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group member should exist.

    .PARAMETER Description
    A description for the DFS Replication Group member.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group this replication
    group is in.
#>
function Set-TargetResource
{
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.SettingRegGroupMemberMessage) `
            -f $GroupName,$ComputerName
        ) -join '' )

    # Lookup the existing Replication Group member
    $memberParameters = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }

    if ($DomainName)
    {
        $memberParameters += @{
            DomainName = $DomainName
        }
    } # if

    $replicationGroupMember = Get-DfsrMember @memberParameters `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The rep group member should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.EnsureReplicationGroupMemberExistsMessage) `
                -f $GroupName,$ComputerName
            ) -join '' )

        if ($Description)
        {
            $memberParameters += @{
                Description = $Description
            }
        } # if

        if ($replicationGroupMember)
        {
            # The RG member exists already - update it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberExistsMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )

            # Check the description
            if (($Description) -and ($replicationGroupMember.Description -ne $Description))
            {
                Set-DfsrMember @memberParameters -ErrorAction Stop

                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupMemberDescriptionUpdatedMessage) `
                        -f $GroupName,$ComputerName
                    ) -join '' )
            } # if
        } # if
        else
        {
            # This Rep Group member doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberDoesNotExistMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )

            Add-DfsrMember @memberParameters -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberCreatedMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )
        } # else
    } #if
    else
    {
        # The Rep Group member should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.EnsureReplicationGroupMemberDoesNotExistMessage) `
                -f $GroupName,$ComputerName
            ) -join '' )

        if ($replicationGroupMember)
        {
            # Remove the replication group member
            Remove-DfsrMember @memberParameters `
                -Force `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberExistsRemovedMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )
        } # if
    } # if
} # Set-TargetResource

<#
    .SYNOPSIS
    Tests DFS Replication Group member.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group member should exist.

    .PARAMETER Description
    A description for the DFS Replication Group member.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group this replication
    group is in.
#>
function Test-TargetResource
{
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $GroupName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.TestingRegGroupMemberMessage) `
            -f $GroupName,$ComputerName
        ) -join '' )

    # Lookup the existing Replication Group member
    $memberParameters = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }

    if ($DomainName)
    {
        $memberParameters += @{
            DomainName = $DomainName
        }
    } # if

    $replicationGroupMember = Get-DfsrMember @memberParameters `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The RG member should exist
        if ($replicationGroupMember)
        {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberExistsMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )

            # Check the description
            if (($Description) -and ($replicationGroupMember.Description -ne $Description))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupMemberDescriptionNeedsUpdateMessage) `
                        -f $GroupName,$ComputerName
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if
        } # if
        else
        {
            # This RG member doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($script:localizedData.ReplicationGroupMemberDoesNotExistButShouldMessage) `
                    -f  $GroupName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # else
    }
    else
    {
        # The RG member should not exist
        if ($replicationGroupMember)
        {
            # The RG member exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($script:localizedData.ReplicationGroupMemberExistsButShouldNotMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if
        else
        {
            # The RG member does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMemberDoesNotExistAndShouldNotMessage) `
                    -f $GroupName,$ComputerName
                ) -join '' )
        } # else
    } # else

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
