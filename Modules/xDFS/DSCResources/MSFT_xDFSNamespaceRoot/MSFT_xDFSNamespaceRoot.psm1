$script:ResourceRootPath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent)

# Import the xCertificate Resource Module (to import the common modules)
Import-Module -Name (Join-Path -Path $script:ResourceRootPath -ChildPath 'xDFS.psd1')

# Import Localization Strings
$localizedData = Get-LocalizedData `
    -ResourceName 'MSFT_xDFSNamespaceRoot' `
    -ResourcePath (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Path,

        [parameter(Mandatory = $true)]
        [String]
        $TargetPath,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [ValidateSet('Standalone','DomainV1','DomainV2')]
        [String]
        $Type
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingNamespaceRootMessage) `
                -f $Type,$Path,$TargetPath
        ) -join '' )

    # Generate the return object assuming absent.
    $ReturnValue = @{
        Path = $Path
        TargetPath = $TargetPath
        Ensure = 'Absent'
        Type = $Type
    }

    # Remove the Ensue parmeter from the bound parameters
    $null = $PSBoundParameters.Remove('Ensure')

    # Lookup the existing Namespace root
    $Root = Get-Root `
        -Path $Path

    if ($Root)
    {
        # The namespace exists
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceRootExistsMessage) `
                    -f $Type,$Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The namespace does not exist
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceRootDoesNotExistMessage) `
                    -f $Type,$Path,$TargetPath
            ) -join '' )
        return $ReturnValue
    }

    $ReturnValue += @{
        TimeToLiveSec                = $Root.TimeToLiveSec
        State                        = $Root.State
        Description                  = $Root.Description
        EnableSiteCosting            = ($Root.Flags -contains 'Site Costing')
        EnableInsiteReferrals        = ($Root.Flags -contains 'Insite Referrals')
        EnableAccessBasedEnumeration = ($Root.Flags -contains 'AccessBased Enumeration')
        EnableRootScalability        = ($Root.Flags -contains 'Root Scalability')
        EnableTargetFailback         = ($Root.Flags -contains 'Target Failback')
    }

    # DFS Root exists but does target exist?
    $Target = Get-RootTarget `
        -Path $Path `
        -TargetPath $TargetPath

    if ($Target)
    {
        # The target exists in this namespace
        $ReturnValue.Ensure = 'Present'
        $ReturnValue += @{
            ReferralPriorityClass        = $Target.ReferralPriorityClass
            ReferralPriorityRank         = $Target.ReferralPriorityRank
        }

        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceRootTargetExistsMessage) `
                    -f $Type,$Path,$TargetPath
            ) -join '' )
    }
    else
    {
        # The target does not exist in this namespace
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceRootTargetDoesNotExistMessage) `
                    -f $Type,$Path,$TargetPath
            ) -join '' )
    }

    return $ReturnValue
} # Get-TargetResource

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Path,

        [parameter(Mandatory = $true)]
        [String]
        $TargetPath,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [ValidateSet('Standalone','DomainV1','DomainV2')]
        [String]
        $Type,

        [String]
        $Description,

        [Uint32]
        $TimeToLiveSec,

        [Boolean]
        $EnableSiteCosting,

        [Boolean]
        $EnableInsiteReferrals,

        [Boolean]
        $EnableAccessBasedEnumeration,

        [Boolean]
        $EnableRootScalability,

        [Boolean]
        $EnableTargetFailback,

        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [String]
        $ReferralPriorityClass,

        [Uint32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceRootMessage) `
                -f $Type,$Path,$TargetPath
        ) -join '' )

    # Lookup the existing Namespace root
    $Root = Get-Root `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # Set desired Configuration
        if ($Root)
        {
            # Does the root need to be updated?
            [boolean] $RootChange = $false

            # The root properties that will be updated
            $RootProperties = @{
                State = 'online'
            }

            if (($Description) `
                -and ($Root.Description -ne $Description))
            {
                $RootProperties += @{
                    Description = $Description
                }
                $RootChange = $true
            }

            if (($TimeToLiveSec) `
                -and ($Root.TimeToLiveSec -ne $TimeToLiveSec))
            {
                $RootProperties += @{
                    TimeToLiveSec = $TimeToLiveSec
                }
                $RootChange = $true
            }

            if (($null -ne $EnableSiteCosting) `
                -and (($Root.Flags -contains 'Site Costing') -ne $EnableSiteCosting))
            {
                $RootProperties += @{
                    EnableSiteCosting = $EnableSiteCosting
                }
                $RootChange = $true
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($Root.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals))
            {
                $RootProperties += @{
                    EnableInsiteReferrals = $EnableInsiteReferrals
                }
                $RootChange = $true
            }

            if (($null -ne $EnableAccessBasedEnumeration) `
                -and (($Root.Flags -contains 'AccessBased Enumeration') -ne $EnableAccessBasedEnumeration))
            {
                $RootProperties += @{
                    EnableAccessBasedEnumeration = $EnableAccessBasedEnumeration
                }
                $RootChange = $true
            }

            if (($null -ne $EnableRootScalability) `
                -and (($Root.Flags -contains 'Root Scalability') -ne $EnableRootScalability))
            {
                $RootProperties += @{
                    EnableRootScalability = $EnableRootScalability
                }
                $RootChange = $true
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($Root.Flags -contains 'Target Failback') -ne $EnableTargetFailback))
            {
                $RootProperties += @{
                    EnableTargetFailback = $EnableTargetFailback
                }
                $RootChange = $true
            }

            if ($RootChange)
            {
                # Update root settings
                $null = Set-DfsnRoot `
                    -Path $Path `
                    @RootProperties `
                    -ErrorAction Stop

                $RootProperties.GetEnumerator() | ForEach-Object -Process {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceRootUpdateParameterMessage) `
                            -f $Type,$Path,$TargetPath,$_.name, $_.value
                    ) -join '' )
                }
            }

            # Get target
            $Target = Get-RootTarget `
                -Path $Path `
                -TargetPath $TargetPath

            # Does the target need to be updated?
            [boolean] $TargetChange = $false

            # The Target properties that will be updated
            $TargetProperties = @{}

            # Check the target properties
            if (($ReferralPriorityClass) `
                -and ($Target.ReferralPriorityClass -ne $ReferralPriorityClass))
            {
                $TargetProperties += @{
                    ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
                }
                $TargetChange = $true
            }

            if (($ReferralPriorityRank) `
                -and ($Target.ReferralPriorityRank -ne $ReferralPriorityRank))
            {
                $TargetProperties += @{
                    ReferralPriorityRank = $ReferralPriorityRank
                }
                $TargetChange = $true
            }

            # Is the target a member of the namespace?
            if ($Target)
            {
                # Does the target need to be changed?
                if ($TargetChange)
                {
                    # Update target settings
                    $null = Set-DfsnRootTarget `
                        -Path $Path `
                        -TargetPath $TargetPath `
                        @TargetProperties `
                        -ErrorAction Stop
                }
            }
            else
            {
                # Add target to Namespace
                $null = New-DfsnRootTarget `
                    -Path $Path `
                    -TargetPath $TargetPath `
                    @TargetProperties `
                    -ErrorAction Stop
            }

            # Output the target parameters that were changed/set
            $TargetProperties.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootTargetUpdateParameterMessage) `
                        -f $Type,$Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
        else
        {
            # Prepare to use the PSBoundParameters as a splat to created
            # The new DFS Namespace root.
            $null = $PSBoundParameters.Remove('Ensure')

            # Correct the ReferralPriorityClass field
            if ($ReferralPriorityClass)
            {
                $PSBoundParameters.ReferralPriorityClass = ($ReferralPriorityClass -replace '-','')
            }

            # Create New-DfsnRoot
            $null = New-DfsnRoot `
                @PSBoundParameters `
                -ErrorAction Stop

            $PSBoundParameters.GetEnumerator() | ForEach-Object -Process {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootUpdateParameterMessage) `
                        -f $Type,$Path,$TargetPath,$_.name, $_.value
                ) -join '' )
            }
        }
    }
    else
    {
        # The Namespace Target should not exist

        # Get root target
        $Target = Get-RootTarget `
            -Path $Path `
            -TargetPath $TargetPath

        if ($Target)
        {
            # Remove the target from the namespace
            $null = Remove-DfsnRootTarget `
                -Path $Path `
                -TargetPath $TargetPath `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceRootTargetRemovedMessage) `
                    -f $Type,$Path,$TargetPath
            ) -join '' )
        }
    }
} # Set-TargetResource

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Path,

        [parameter(Mandatory = $true)]
        [String]
        $TargetPath,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,

        [parameter(Mandatory = $true)]
        [ValidateSet('Standalone','DomainV1','DomainV2')]
        [String]
        $Type,

        [String]
        $Description,

        [Uint32]
        $TimeToLiveSec,

        [Boolean]
        $EnableSiteCosting,

        [Boolean]
        $EnableInsiteReferrals,

        [Boolean]
        $EnableAccessBasedEnumeration,

        [Boolean]
        $EnableRootScalability,

        [Boolean]
        $EnableTargetFailback,

        [ValidateSet('Global-High','SiteCost-High','SiteCost-Normal','SiteCost-Low','Global-Low')]
        [String]
        $ReferralPriorityClass,

        [Uint32]
        $ReferralPriorityRank
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceRootMessage) `
                -f $Type,$Path,$TargetPath
        ) -join '' )

    # Flag to signal whether settings are correct
    [Boolean] $DesiredConfigurationMatch = $true

    # Lookup the existing Namespace root
    $Root = Get-Root `
        -Path $Path

    if ($Ensure -eq 'Present')
    {
        # The Namespace root should exist
        if ($Root)
        {
            # The Namespace root exists and should

            # Changing the namespace type is not possible - the namespace
            # can only be recreated if the type should change.
            if (($Root.Type -replace ' ','') -ne $Type)
            {
                $ErrorParam = @{
                    ErrorId = 'NamespaceTypeConversionError'
                    ErrorMessage = $($LocalizedData.NamespaceRootTypeConversionError) `
                        -f $Type,$Path,$TargetPath,($Root.Type -replace ' ','')
                    ErrorCategory = 'InvalidOperation'
                    ErrorAction = 'Stop'
                }
                New-TerminatingError @ErrorParam
            }

            # Check the Namespace parameters
            if (($Description) `
                -and ($Root.Description -ne $Description)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'Description'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($TimeToLiveSec) `
                -and ($Root.TimeToLiveSec -ne $TimeToLiveSec)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'TimeToLiveSec'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableSiteCosting) `
                -and (($Root.Flags -contains 'Site Costing') -ne $EnableSiteCosting)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'EnableSiteCosting'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableInsiteReferrals) `
                -and (($Root.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'EnableInsiteReferrals'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableAccessBasedEnumeration) `
                -and (($Root.Flags -contains 'AccessBased Enumeration') -ne $EnableAccessBasedEnumeration)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'EnableAccessBasedEnumeration'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableRootScalability) `
                -and (($Root.Flags -contains 'Root Scalability') -ne $EnableRootScalability)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'EnableRootScalability'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($null -ne $EnableTargetFailback) `
                -and (($Root.Flags -contains 'Target Failback') -ne $EnableTargetFailback)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootParameterNeedsUpdateMessage) `
                        -f $Type,$Path,$TargetPath,'EnableTargetFailback'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            $Target = Get-RootTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($Target)
            {
                if (($ReferralPriorityClass) `
                    -and ($Target.ReferralPriorityClass -ne $ReferralPriorityClass)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceRootTargetParameterNeedsUpdateMessage) `
                            -f $Type,$Path,$TargetPath,'ReferralPriorityClass'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }

                if (($ReferralPriorityRank) `
                    -and ($Target.ReferralPriorityRank -ne $ReferralPriorityRank)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceRootTargetParameterNeedsUpdateMessage) `
                            -f $Type,$Path,$TargetPath,'ReferralPriorityRank'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }
            }
            else
            {
                # The Root target does not exist but should - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootTargetDoesNotExistButShouldMessage) `
                        -f $Type,$Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
        }
        else
        {
            # Ths Namespace root doesn't exist but should - change required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceRootDoesNotExistButShouldMessage) `
                    -f $Type,$Path,$TargetPath
                ) -join '' )
            $desiredConfigurationMatch = $false
        }
    }
    else
    {
        # The Namespace target should not exist
        if ($Root)
        {
            $Target = Get-RootTarget `
                -Path $Path `
                -TargetPath $TargetPath

            if ($Target)
            {
                # The Root target exists but should not - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootTargetExistsButShouldNotMessage) `
                        -f $Type,$Path,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
            else
            {
                # The Namespace exists but the target doesn't - change not required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceRootTargetDoesNotExistAndShouldNotMessage) `
                        -f $Type,$Path,$TargetPath
                    ) -join '' )
            }
        }
        else
        {
            # The Namespace does not exist (so neither does the target) - change not required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceRootDoesNotExistAndShouldNotMessage) `
                    -f $Type,$Path,$TargetPath
                ) -join '' )
        }
    } # if

    return $DesiredConfigurationMatch

} # Test-TargetResource

# Helper Functions
Function Get-Root {
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Path
    )
    # Lookup the DFSN Root.
    # Return null if doesn't exist.
    try
    {
        $DfsnRoot = Get-DfsnRoot `
            -Path $Path `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $DfsnRoot = $null
    }
    catch
    {
        Throw $_
    }
    Return $DfsnRoot
}

Function Get-RootTarget {
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Path,

        [parameter(Mandatory = $true)]
        [String]
        $TargetPath
    )
    # Lookup the DFSN Root Target in a namespace.
    # Return null if doesn't exist.
    try
    {
        $DfsnTarget = Get-DfsnRootTarget `
            -Path $Path `
            -TargetPath $TargetPath `
            -ErrorAction Stop
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $DfsnTarget = $null
    }
    catch
    {
        Throw $_
    }
    Return $DfsnTarget
}

function New-TerminatingError
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [String] $ErrorId,

        [Parameter(Mandatory)]
        [String] $ErrorMessage,

        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorCategory] $ErrorCategory
    )

    $exception = New-Object `
        -TypeName System.InvalidOperationException `
        -ArgumentList $errorMessage
    $errorRecord = New-Object `
        -TypeName System.Management.Automation.ErrorRecord `
        -ArgumentList $exception, $errorId, $errorCategory, $null
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

Export-ModuleMember -Function *-TargetResource
