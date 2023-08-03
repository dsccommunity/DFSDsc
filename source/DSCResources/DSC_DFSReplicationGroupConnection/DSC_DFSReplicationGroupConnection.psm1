$modulePath = Join-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -ChildPath 'Modules'

# Import the DFSDsc.Common Module
Import-Module -Name (Join-Path -Path $modulePath -ChildPath 'DscResource.Common')

# Import Localization Strings
$script:localizedData = Get-LocalizedData -DefaultUICulture 'en-US'

<#
    .SYNOPSIS
    Returns the current state of a DFS Replication Group Connection.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER SourceComputerName
    The name of the Replication Group source computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER DestinationComputerName
    The name of the Replication Group destination computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group should exist.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group connection should be in.
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
        $SourceComputerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationComputerName,

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
        $($script:localizedData.GettingReplicationGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName
        ) -join '' )

    # Lookup the existing Replication Group Connection
    $connectionParameters = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }

    $returnValue = $connectionParameters.Clone()

    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $connectionParameters += @{
            DomainName = $DomainName
        }
    } # if

    $replicationGroupConnection = Get-DfsrConnection @connectionParameters `
        -ErrorAction Stop

    if ($replicationGroupConnection)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName
            ) -join '' )

        $returnValue.SourceComputerName = $replicationGroupConnection.SourceComputerName
        $returnValue.DestinationComputerName = $replicationGroupConnection.DestinationComputerName

        if ($replicationGroupConnection.Enabled)
        {
            $ensureEnabled = 'Enabled'
        }
        else
        {
            $ensureEnabled = 'Disabled'
        } # if

        if ($replicationGroupConnection.RdcEnabled)
        {
            $ensureRDCEnabled = 'Enabled'
        }
        else
        {
            $ensureRDCEnabled = 'Disabled'
        } # if

        if ($replicationGroupConnection.CrossFileRdcEnabled)
        {
            $ensureCrossFileRDCEnabled = 'Enabled'
        }
        else
        {
            $ensureCrossFileRDCEnabled = 'Disabled'
        } # if

        $returnValue += @{
            Ensure = 'Present'
            Description = $replicationGroupConnection.Description
            DomainName = $replicationGroupConnection.DomainName
            EnsureEnabled = $ensureEnabled
            EnsureRDCEnabled = $ensureRDCEnabled
            EnsureCrossFileRDCEnabled = $ensureCrossFileRDCEnabled
            MinimumRDCFileSizeInKB = $replicationGroupConnection.MinimumRDCFileSizeInKB
        }
    }
    else
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.ReplicationGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName
            ) -join '' )

        $returnValue += @{
            Ensure = 'Absent'
        }
    } # if

    return $returnValue
} # Get-TargetResource

<#
    .SYNOPSIS
    Sets the current state of a DFS Replication Group Connection.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER SourceComputerName
    The name of the Replication Group source computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER DestinationComputerName
    The name of the Replication Group destination computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group should exist.

    .PARAMETER Description
    A description for the DFS Replication Group connection.

    .PARAMETER EnsureEnabled
    Ensures that connection is either Enabled or Disabled.

    .PARAMETER EnsureRDCEnabled
    Ensures remote differential compression is Enabled or Disabled.

    .PARAMETER EnsureCrossFileRDCEnabled
    Ensures cross-file similarity remote differential compression is Enabled or Disabled.

    .PARAMETER MinimumRDCFileSizeInKB
    The file size threshold for RDC to apply in KB.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group connection should be in.
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
        $SourceComputerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationComputerName,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureEnabled = 'Enabled',

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureRDCEnabled = 'Enabled',

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureCrossFileRDCEnabled = 'Enabled',

        [Parameter()]
        [System.UInt32]
        $MinimumRDCFileSizeInKB,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.SettingReplicationGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName
        ) -join '' )

    # Remove Ensure so the PSBoundParameters can be used to splat
    $null = $PSBoundParameters.Remove('Ensure')
    $null = $PSBoundParameters.Remove('EnsureEnabled')
    $null = $PSBoundParameters.Remove('EnsureRDCEnabled')
    $null = $PSBoundParameters.Remove('EnsureCrossFileRDCEnabled')

    # Lookup the existing Replication Group Connection
    $connectionParameters = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }

    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $connectionParameters += @{
            DomainName = $DomainName
        }
    } # if

    $replicationGroupConnection = Get-DfsrConnection @connectionParameters -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The rep group connection should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.EnsureReplicationGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName
            ) -join '' )

        $null = $PSBoundParameters.Add('DisableConnection',($EnsureEnabled -eq 'Disabled'))
        $null = $PSBoundParameters.Add('DisableRDC',($EnsureRDCEnabled -eq 'Disabled'))
        $null = $PSBoundParameters.Add('DisableCrossFileRDC',($EnsureCrossFileRDCEnabled -eq 'Disabled'))

        if ($replicationGroupConnection)
        {
            # The RG connection exists already - update it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )

            Set-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionUpdatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )
        }
        else
        {
            # Ths Rep Groups doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionDoesNotExistMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )

            Add-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionCreatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )
        } # if
    }
    else
    {
        # The Rep Group should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($script:localizedData.EnsureReplicationGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName
            ) -join '' )

        if ($replicationGroupConnection)
        {
            # Remove the replication group
            Remove-DfsrConnection @connectionParameters -Force -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionExistsRemovedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )
        }
    } # if
} # Set-TargetResource

<#
    .SYNOPSIS
    Tests the current state of a DFS Replication Group Connection.

    .PARAMETER GroupName
    The name of the DFS Replication Group.

    .PARAMETER SourceComputerName
    The name of the Replication Group source computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER DestinationComputerName
    The name of the Replication Group destination computer for the
    connection. This can be specified using either the ComputerName
    or FQDN name for the member. If an FQDN name is used and the
    DomainName parameter is set, the FQDN domain name must match.

    .PARAMETER Ensure
    Specifies whether the DFS Replication Group should exist.

    .PARAMETER Description
    A description for the DFS Replication Group connection.

    .PARAMETER EnsureEnabled
    Ensures that connection is either Enabled or Disabled.

    .PARAMETER EnsureRDCEnabled
    Ensures remote differential compression is Enabled or Disabled.

    .PARAMETER EnsureCrossFileRDCEnabled
    Ensures cross-file similarity remote differential compression is Enabled or Disabled.

    .PARAMETER MinimumRDCFileSizeInKB
    The file size threshold for RDC to apply in KB.

    .PARAMETER DomainName
    The name of the AD Domain the DFS Replication Group connection should be in.
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
        $SourceComputerName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $DestinationComputerName,

        [Parameter()]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Description,

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureEnabled = 'Enabled',

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureRDCEnabled = 'Enabled',

        [Parameter()]
        [ValidateSet('Enabled','Disabled')]
        [System.String]
        $EnsureCrossFileRDCEnabled = 'Enabled',

        [Parameter()]
        [System.UInt32]
        $MinimumRDCFileSizeInKB,

        [Parameter()]
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($script:localizedData.TestingReplicationGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName
        ) -join '' )

    # Remove Ensure so the PSBoundParameters can be used to splat
    $null = $PSBoundParameters.Remove('Ensure')

    # Lookup the existing Replication Group Connection
    $connectionParameters = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }

    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $connectionParameters += @{
            DomainName = $DomainName
        }
    }

    $replicationGroupConnection = Get-DfsrConnection @connectionParameters `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The RG should exist
        if ($replicationGroupConnection)
        {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )

            # Check if any of the non-key paramaters are different.
            if (($PSBoundParameters.ContainsKey('Description')) -and `
                ($replicationGroupConnection.Description -ne $Description))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,'Description'
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if

            if (($EnsureEnabled -eq 'Enabled') `
                -and (-not $replicationGroupConnection.Enabled) `
                -or ($EnsureEnabled -eq 'Disabled') `
                -and ($replicationGroupConnection.Enabled))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,'Enabled'
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if

            if (($EnsureRDCEnabled -eq 'Enabled') `
                -and (-not $replicationGroupConnection.RDCEnabled) `
                -or ($EnsureRDCEnabled -eq 'Disabled') `
                -and ($replicationGroupConnection.RDCEnabled))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,'RDC Enabled'
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if

            if (($EnsureCrossFileRDCEnabled -eq 'Enabled') `
                -and (-not $replicationGroupConnection.CrossFileRDCEnabled) `
                -or ($EnsureCrossFileRDCEnabled -eq 'Disabled') `
                -and ($replicationGroupConnection.CrossFileRDCEnabled))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,'Cross File RDC Enabled'
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if

            if (($PSBoundParameters.ContainsKey('MinimumRDCFileSizeInKB')) -and `
                ($replicationGroupConnection.MinimumRDCFileSizeInKB -ne $MinimumRDCFileSizeInKB))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($script:localizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,'Minimum RDC File Size'
                    ) -join '' )

                $desiredConfigurationMatch = $false
            } # if
        }
        else
        {
            # Ths RG doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($script:localizedData.ReplicationGroupConnectionDoesNotExistButShouldMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        } # if
    }
    else
    {
        # The RG should not exist
        if ($replicationGroupConnection)
        {
            # The RG exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($script:localizedData.ReplicationGroupConnectionExistsButShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )

            $desiredConfigurationMatch = $false
        }
        else
        {
            # The RG does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($script:localizedData.ReplicationGroupConnectionDoesNotExistAndShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName
                ) -join '' )
        } # if
    } # if

    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
