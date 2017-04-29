$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSReplicationGroupConnection' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

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
    Specifies whether the DSF Replication Group should exist.

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

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

        [Parameter()]
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingReplicationGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
        ) -join '' )

    # Lookup the existing Replication Group Connection
    $Splat = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }
    $returnValue = $splat.Clone()
    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupConnection = Get-DfsrConnection @Splat `
        -ErrorAction Stop
    if ($ReplicationGroupConnection)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )
        $returnValue.SourceComputerName = $ReplicationGroupConnection.SourceComputerName
        $returnValue.DestinationComputerName = $ReplicationGroupConnection.DestinationComputerName
        if ($ReplicationGroupConnection.Enabled)
        {
            $EnsureEnabled = 'Enabled'
        }
        else
        {
            $EnsureEnabled = 'Disabled'
        } # if
        if ($ReplicationGroupConnection.RdcEnabled)
        {
            $EnsureRDCEnabled = 'Enabled'
        }
        else
        {
            $EnsureRDCEnabled = 'Disabled'
        } # if
        $returnValue += @{
            Ensure = 'Present'
            Description = $ReplicationGroupConnection.Description
            DomainName = $ReplicationGroupConnection.DomainName
            EnsureEnabled = $EnsureEnabled
            EnsureRDCEnabled = $EnsureRDCEnabled
        }
    }
    else
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.ReplicationGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )
        $returnValue += @{ Ensure = 'Absent' }
    }

    $returnValue
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
    Specifies whether the DSF Replication Group should exist.

    .PARAMETER Description
    A description for the DFS Replication Group connection.

    .PARAMETER EnsureEnabled
    Ensures that connection is either Enabled or Disabled.

    .PARAMETER EnsureRDCEnabled
    Ensures remote differential compression is Enabled or Disabled.

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

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

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
        [System.String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
        ) -join '' )

    # Remove Ensure so the PSBoundParameters can be used to splat
    $null = $PSBoundParameters.Remove('Ensure')
    $null = $PSBoundParameters.Remove('EnsureEnabled')
    $null = $PSBoundParameters.Remove('EnsureRDCEnabled')

    # Lookup the existing Replication Group Connection
    $Splat = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }
    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupConnection = Get-DfsrConnection @Splat -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The rep group connection should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureReplicationGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )

        $null = $PSBoundParameters.Add('DisableConnection',($EnsureEnabled -eq 'Disabled'))
        $null = $PSBoundParameters.Add('DisableRDC',($EnsureRDCEnabled -eq 'Disabled'))

        if ($ReplicationGroupConnection)
        {
            # The RG connection exists already - update it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            Set-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionUpdatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

        }
        else
        {
            # Ths Rep Groups doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionDoesNotExistMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            Add-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionCreatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

        }
    }
    else
    {
        # The Rep Group should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureReplicationGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )
        if ($ReplicationGroup)
        {
            # Remove the replication group
            Remove-DfsrConnection @Splat -Force -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionExistsRemovedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
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
    Specifies whether the DSF Replication Group should exist.

    .PARAMETER Description
    A description for the DFS Replication Group connection.

    .PARAMETER EnsureEnabled
    Ensures that connection is either Enabled or Disabled.

    .PARAMETER EnsureRDCEnabled
    Ensures remote differential compression is Enabled or Disabled.

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

        [Parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [System.String]
        $Ensure,

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
        [System.String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [System.Boolean] $desiredConfigurationMatch = $true

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.TestingRegGroupConnectionMessage) `
            -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
        ) -join '' )

    # Remove Ensure so the PSBoundParameters can be used to splat
    $null = $PSBoundParameters.Remove('Ensure')

    # Lookup the existing Replication Group Connection
    $Splat = @{
        GroupName = $GroupName
        SourceComputerName = $SourceComputerName
        DestinationComputerName = $DestinationComputerName
    }
    if ($PSBoundParameters.ContainsKey('DomainName'))
    {
        $Splat += @{ DomainName = $DomainName }
    }
    $ReplicationGroupConnection = Get-DfsrConnection @Splat `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The RG should exist
        if ($ReplicationGroupConnection)
        {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

            # Check if any of the non-key paramaters are different.
            if (($PSBoundParameters.ContainsKey('Description')) -and `
                ($ReplicationGroupConnection.Description -ne $Description))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName, `
                        'Description'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnsureEnabled -eq 'Enabled') `
                -and (-not $ReplicationGroupConnection.Enabled) `
                -or ($EnsureEnabled -eq 'Disabled') `
                -and ($ReplicationGroupConnection.Enabled))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName, `
                        'Enabled'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnsureRDCEnabled -eq 'Enabled') `
                -and (-not $ReplicationGroupConnection.RDCEnabled) `
                -or ($EnsureRDCEnabled -eq 'Disabled') `
                -and ($ReplicationGroupConnection.RDCEnabled))
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.ReplicationGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName, `
                        'RDC Enabled'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
        }
        else
        {
            # Ths RG doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.ReplicationGroupConnectionDoesNotExistButShouldMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The RG should not exist
        if ($ReplicationGroupConnection)
        {
            # The RG exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.ReplicationGroupConnectionExistsButShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        else
        {
            # The RG does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.ReplicationGroupConnectionDoesNotExistAndShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
        }
    } # if
    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource
