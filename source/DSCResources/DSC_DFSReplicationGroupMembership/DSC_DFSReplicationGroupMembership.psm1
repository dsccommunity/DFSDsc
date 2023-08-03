$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the DFSDsc.Common Module
Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
    Returns the current state of a DFS Replication Group Membership.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER FolderName
    The name of the DFS Replication Group Folder.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

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
        $FolderName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.GettingReplicationGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName
        ) -join '' )

    # Lookup the existing Replication Group
    $membershipParameters = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }

    $returnValue = $membershipParameters

    if ($DomainName)
    {
        $membershipParameters += @{
            DomainName = $DomainName
        }
    }

    $returnValue += @{
        FolderName = $FolderName
    }

    $replicationGroupMembership = Get-DfsrMembership @membershipParameters `
        -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }

    if ($replicationGroupMembership)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName
            ) -join '' )

        $returnValue.ComputerName = $replicationGroupMembership.ComputerName

        if ($replicationGroupMembership.Enabled)
        {
            $ensureEnabled = 'Enabled'
        }
        else
        {
            $ensureEnabled = 'Disabled'
        } # if

        $returnValue += @{
            EnsureEnabled = $ensureEnabled
            ContentPath = $replicationGroupMembership.ContentPath
            StagingPath = $replicationGroupMembership.StagingPath
            StagingPathQuotaInMB = $replicationGroupMembership.StagingPathQuotaInMB
            MinimumFileStagingSize = $replicationGroupMembership.MinimumFileStagingSize
            ConflictAndDeletedPath = $replicationGroupMembership.ConflictAndDeletedPath
            ConflictAndDeletedQuotaInMB = $replicationGroupMembership.ConflictAndDeletedQuotaInMB
            ReadOnly = $replicationGroupMembership.ReadOnly
            RemoveDeletedFiles = $replicationGroupMembership.RemoveDeletedFiles
            PrimaryMember = $replicationGroupMembership.PrimaryMember
            DfsnPath = $replicationGroupMembership.DfsnPath
            DomainName = $replicationGroupMembership.DomainName
        }
    }
    else
    {
        # The Rep Group membership doesn't exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMembershipDoesNotExistMessage) `
                -f $GroupName,$FolderName,$ComputerName
            ) -join '' )
    }

    return $returnValue
} # Get-TargetResource

<#
    .SYNOPSIS
    Sets DFS Replication Group Membership.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER FolderName
    The name of the DFS Replication Group Folder.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

    .PARAMETER EnsureEnabled
    Ensures that membership is either Enabled or Disabled.

    .PARAMETER ContentPath
    The local content path for the DFS Replication Group Folder.

    .PARAMETER StagingPath
    The local staging path for the DFS Replication Group Folder.

    .PARAMETER StagingPathQuotaInMB
    The local staging path quota size in MB.

    .PARAMETER MinimumFileStagingSize
    The minimum file size that DFS Replication stages during outbound replication.

    .PARAMETER ConflictAndDeletedQuotaInMB
    The local conflict and deleted path quota size in MB.

    .PARAMETER ReadOnly
    Specify if this content path should be read only.

    .PARAMETER RemoveDeletedFiles
    Specify if a member computer deletes files and folders immediately following inbound replication.

    .PARAMETER PrimaryMember
    Used to configure this as the Primary Member. Every folder must
    have at least one primary member for initial replication to take
    place.

    .PARAMETER DfsnPath
    Specify the DFS Namespace folder path of the membership. This value does not affect replication.

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
        $FolderName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureEnabled = 'Enabled',

        [Parameter()]
        [System.String]
        $ContentPath,

        [Parameter()]
        [System.String]
        $StagingPath,

        [Parameter()]
        [System.UInt32]
        $StagingPathQuotaInMB,

        [Parameter()]
        [ValidateSet('Size256KB','Size512KB',
            'Size1MB','Size2MB','Size4MB','Size8MB','Size16MB','Size32MB','Size64MB','Size128MB','Size256MB','Size512MB',
            'Size1GB','Size2GB','Size4GB','Size8GB','Size16GB','Size32GB','Size64GB','Size128GB','Size256GB','Size512GB',
            'Size1TB','Size2TB','Size4TB','Size8TB','Size16TB','Size32TB','Size64TB','Size128TB','Size256TB','Size512TB')]
        [System.String]
        $MinimumFileStagingSize,

        [Parameter()]
        [System.UInt32]
        $ConflictAndDeletedQuotaInMB,

        [Parameter()]
        [System.Boolean]
        $ReadOnly,

        [Parameter()]
        [System.Boolean]
        $RemoveDeletedFiles,

        [Parameter()]
        [System.Boolean]
        $PrimaryMember,

        [Parameter()]
        [System.String]
        $DfsnPath,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.SettingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName
        ) -join '' )

    # Remove Ensure so the PSBoundParameters can be used to splat
    $null = $PSBoundParameters.Remove('EnsureEnabled')

    $null = $PSBoundParameters.Add('DisableMembership',($EnsureEnabled -eq 'Disabled'))

    # Now apply the changes
    Set-DfsrMembership @PSBoundParameters `
        -ErrorAction Stop

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.ReplicationGroupMembershipUpdatedMessage) `
            -f $GroupName,$FolderName,$ComputerName
        ) -join '' )
} # Set-TargetResource

<#
    .SYNOPSIS
    Tests DFS Replication Group Membership.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER FolderName
    The name of the DFS Replication Group Folder.

    .PARAMETER ComputerName
    The computer name of the Replication Group member. This can be
    specified using either the ComputerName or FQDN name for the member.
    If an FQDN name is used and the DomainName parameter is set, the FQDN
    domain name must match.

    .PARAMETER EnsureEnabled
    Ensures that membership is either Enabled or Disabled.

    .PARAMETER ContentPath
    The local content path for the DFS Replication Group Folder.

    .PARAMETER StagingPath
    The local staging path for the DFS Replication Group Folder.

    .PARAMETER StagingPathQuotaInMB
    The local staging path quota size in MB.

    .PARAMETER MinimumFileStagingSize
    The minimum file size that DFS Replication stages during outbound replication.

    .PARAMETER ConflictAndDeletedQuotaInMB
    The local conflict and deleted path quota size in MB.

    .PARAMETER ReadOnly
    Specify if this content path should be read only.

    .PARAMETER RemoveDeletedFiles
    Specify if a member computer deletes files and folders immediately following inbound replication.

    .PARAMETER PrimaryMember
    Used to configure this as the Primary Member. Every folder must
    have at least one primary member for initial replication to take
    place.

    .PARAMETER DfsnPath
    Specify the DFS Namespace folder path of the membership. This value does not affect replication.

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
        $FolderName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ComputerName,

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureEnabled = 'Enabled',

        [Parameter()]
        [System.String]
        $ContentPath,

        [Parameter()]
        [System.String]
        $StagingPath,

        [Parameter()]
        [System.UInt32]
        $StagingPathQuotaInMB,

        [Parameter()]
        [ValidateSet('Size256KB','Size512KB',
            'Size1MB','Size2MB','Size4MB','Size8MB','Size16MB','Size32MB','Size64MB','Size128MB','Size256MB','Size512MB',
            'Size1GB','Size2GB','Size4GB','Size8GB','Size16GB','Size32GB','Size64GB','Size128GB','Size256GB','Size512GB',
            'Size1TB','Size2TB','Size4TB','Size8TB','Size16TB','Size32TB','Size64TB','Size128TB','Size256TB','Size512TB')]
        [System.String]
        $MinimumFileStagingSize,

        [Parameter()]
        [System.UInt32]
        $ConflictAndDeletedQuotaInMB,

        [Parameter()]
        [System.Boolean]
        $ReadOnly,

        [Parameter()]
        [System.Boolean]
        $RemoveDeletedFiles,

        [Parameter()]
        [System.Boolean]
        $PrimaryMember,

        [Parameter()]
        [System.String]
        $DfsnPath,

        [Parameter()]
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.TestingRegGroupMembershipMessage) `
            -f $GroupName,$FolderName,$ComputerName
        ) -join '' )

    # Lookup the existing Replication Group
    $membershipParameters = @{
        GroupName = $GroupName
        ComputerName = $ComputerName
    }

    if ($DomainName)
    {
        $membershipParameters += @{
            DomainName = $DomainName
        }
    }

    $replicationGroupMembership = Get-DfsrMembership @membershipParameters `
        -ErrorAction Stop `
        | Where-Object { $_.FolderName -eq $FolderName }

    if ($replicationGroupMembership)
    {
        # The rep group folder is found
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMembershipExistsMessage) `
                -f $GroupName,$FolderName,$ComputerName
            ) -join '' )

        # Check the Enabled
        if (($EnsureEnabled -eq 'Enabled') `
            -and (-not $replicationGroupMembership.Enabled) `
            -or ($EnsureEnabled -eq 'Disabled') `
            -and ($replicationGroupMembership.Enabled))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipEnabledMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the ContentPath
        if (($PSBoundParameters.ContainsKey('ContentPath')) `
            -and ($replicationGroupMembership.ContentPath -ne $ContentPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipContentPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the StagingPath
        if (($PSBoundParameters.ContainsKey('StagingPath')) `
            -and ($replicationGroupMembership.StagingPath -ne $StagingPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipStagingPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the StagingPathQuota
        if (($PSBoundParameters.ContainsKey('StagingPathQuotaInMB')) `
            -and ($replicationGroupMembership.StagingPathQuotaInMB -ne $StagingPathQuotaInMB))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipStagingPathQuotaMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the MinimumFileStagingSize
        if (($PSBoundParameters.ContainsKey('MinimumFileStagingSize')) `
            -and ($replicationGroupMembership.MinimumFileStagingSize -ne $MinimumFileStagingSize))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipMinimumFileStagingMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the ConflictAndDeletedQuotaInMB
        if (($PSBoundParameters.ContainsKey('ConflictAndDeletedQuotaInMB')) `
            -and ($replicationGroupMembership.ConflictAndDeletedQuotaInMB -ne $ConflictAndDeletedQuotaInMB))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipConflictAndDeletedMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the ReadOnly
        if (($PSBoundParameters.ContainsKey('ReadOnly')) `
            -and ($replicationGroupMembership.ReadOnly -ne $ReadOnly))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipReadOnlyMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the RemoveDeletedFiles
        if (($PSBoundParameters.ContainsKey('RemoveDeletedFiles')) `
            -and ($replicationGroupMembership.RemoveDeletedFiles -ne $RemoveDeletedFiles))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipRemoveDeletedFilesMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the PrimaryMember
        if (($PSBoundParameters.ContainsKey('PrimaryMember')) `
            -and ($replicationGroupMembership.PrimaryMember -ne $PrimaryMember))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipPrimaryMemberMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if

        # Check the DfsnPath
        if (($PSBoundParameters.ContainsKey('DfsnPath')) `
            -and ($replicationGroupMembership.DfsnPath -ne $DfsnPath))
        {
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupMembershipDfsnPathMismatchMessage) `
                    -f $GroupName,$FolderName,$ComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if
    }
    else
    {
        # The Rep Group membership doesn't exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupMembershipDoesNotExistMessage) `
                -f $GroupName,$FolderName,$ComputerName
            ) -join '' )

        $desiredConfigurationMatch = $false
    } # if

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
