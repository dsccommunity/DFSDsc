data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
GettingRepGroupMessage=Getting DFS Replication Group Connection "{0}" from "{1}" to "{2}".
RepGroupConnectionExistsMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" exists.
RepGroupConnectionDoesNotExistMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" does not exist.
SettingRegGroupConnectionMessage=Setting DFS Replication Group Connection "{0}" from "{1}" to "{2}".
EnsureRepGroupConnectionExistsMessage=Ensuring DFS Replication Group "{0}" from "{1}" to "{2}" exists.
EnsureRepGroupConnectionDoesNotExistMessage=Ensuring DFS Replication Group "{0}" from "{1}" to "{2}" does not exist.
RepGroupConnectionCreatedMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" has been created.
RepGroupConnectionUpdatedMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" description has been updated.
RepGroupConnectionExistsRemovedMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" existed, but has been removed.
TestingConnectionRegGroupMessage=Testing DFS Replication Group Connection "{0}" from "{1}" to "{2}".
RepGroupConnectionNeedsUpdateMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" description is different. Change required.
RepGroupConnectionDoesNotExistButShouldMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" does not exist but should. Change required.
RepGroupConnectionExistsButShouldNotMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" exists but should not. Change required.
RepGroupConnectionDoesNotExistAndShouldNotMessage=DFS Replication Group Connection "{0}" from "{1}" to "{2}" does not exist and should not. Change not required.
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
        [String]
        $SourceComputerName,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationComputerName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $DomainName
    )
    
    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.GettingRepGroupConnectionMessage) `
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
    $RepGroupConnection = Get-DfsrConnection @Splat `
        -ErrorAction Stop
    if ($RepGroupConnection)
    {
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )
        $returnValue.SourceComputerName = $RepGroupConnection.SourceComputerName 
        $returnValue.DestinationComputerName = $RepGroupConnection.DestinationComputerName 
        $returnValue += @{
            Ensure = 'Present'
            Description = $RepGroupConnection.Description
            DomainName = $RepGroupConnection.DomainName
            DisableConnection = (-not $RepGroupConnection.Enabled)
            DisableRDC = (-not $RepGroupConnection.RdcEnabled)
        }
    }
    else
    {       
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.RepGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
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
        [String]
        $SourceComputerName,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationComputerName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [Boolean]
        $DisableConnection = $false,

        [Boolean]
        $DisableRDC = $false,

        [String]
        $DomainName
    )

    Write-Verbose -Message ( @(
        "$($MyInvocation.MyCommand): "
        $($LocalizedData.SettingRegGroupConnectionMessage) `
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
    $RepGroupConnection = Get-DfsrConnection @Splat -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The rep group connection should exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupConnectionExistsMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )

        if ($RepGroupConnection)
        {
            # The RG connection exists already - update it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            Set-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionUpdatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

        }
        else
        {
            # Ths Rep Groups doesn't exist - Create it
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionDoesNotExistMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            Add-DfsrConnection @PSBoundParameters `
                -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionCreatedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

        }
    }
    else
    {
        # The Rep Group should not exist
        Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.EnsureRepGroupConnectionDoesNotExistMessage) `
                -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
            ) -join '' )
        if ($RepGroup)
        {
            # Remove the replication group
            Remove-DfsrConnection @Splat -Force -ErrorAction Stop
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionExistsRemovedMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
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
        [String]
        $SourceComputerName,

        [parameter(Mandatory = $true)]
        [String]
        $DestinationComputerName,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [String]
        $Description,

        [Boolean]
        $DisableConnection = $false,

        [Boolean]
        $DisableRDC = $false,

        [String]
        $DomainName
    )

    # Flag to signal whether settings are correct
    [Boolean] $desiredConfigurationMatch = $true

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
    $RepGroupConnection = Get-DfsrConnection @Splat `
        -ErrorAction Stop

    if ($Ensure -eq 'Present')
    {
        # The RG should exist
        if ($RepGroupConnection)
        {
            # The RG exists already
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionExistsMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )

            # Check if any of the non-key paramaters are different.
            if (    
                    (($PSBoundParameters.ContainsKey('Description')) -and ($RepGroupConnection.Description -ne $Description)) `
                -or (($PSBoundParameters.ContainsKey('DisableConnection')) -and ($RepGroupConnection.Enabled -eq $DisableConnection)) `
                -or (($PSBoundParameters.ContainsKey('DisableRDC')) -and ($RepGroupConnection.RDCEnabled -eq $DisableRDC))
                )
            {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.RepGroupConnectionNeedsUpdateMessage) `
                        -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
        }
        else
        {
            # Ths RG doesn't exist but should
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupConnectionDoesNotExistButShouldMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The RG should not exist
        if ($RepGroupConnection)
        {
            # The RG exists but should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.RepGroupConnectionExistsButShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
        else
        {
            # The RG does not exist and should not
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.RepGroupConnectionDoesNotExistAndShouldNotMessage) `
                    -f $GroupName,$SourceComputerName,$DestinationComputerName,$DomainName
                ) -join '' )
        }
    } # if
    return $desiredConfigurationMatch
} # Test-TargetResource

Export-ModuleMember -Function *-TargetResource