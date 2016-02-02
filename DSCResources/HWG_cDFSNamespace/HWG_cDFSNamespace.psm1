data LocalizedData
{
# culture="en-US"
ConvertFrom-StringData -StringData @'
GettingNamespaceMessage=Getting DFS Namespace "{0}" from "{1}.{2}".
NamespaceExistsMessage=DFS Namespace "{0}" on "{1}.{2}" exists.
NamespaceDoesNotExistMessage=DFS Namespace "{0}" on "{1}.{2}" does not exist.
NamespaceTargetExistsMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" exists.
NamespaceTargetDoesNotExistMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" does not exist.
SettingNamespaceMessage=Setting DFS Namespace "{0}" on "{1}.{2}".
NamespaceUpdateParameterMessage=Setting DFS Namespace "{0}" on "{1}.{2}" parameter {3} to "{4}".
NamespaceCreatedMessage=DFS Namespace "{0}" on "{1}.{2}" created.
NamespaceTargetRemovedMessage=DFS Namespace "{0}" on "{1}.{2}" target "{3}" removed.
TestingNamespaceMessage=Testing DFS Namespace "{0}" on "{1}.{2}".
NamespaceTypeConversionError=Error- {3} DFS Namespace can not be added to non-{3} DFS Namespace "{0}" on "{1}.{2}". 
NamespaceParameterNeedsUpdateMessage=DFS Namespace "{0}" on "{1}.{2}" {3} is different. Change required.
NamespaceDoesNotExistButShouldMessage=DFS Namespace "{0}" on "{1}.{2}" does not exist but should. Change required.
NamespaceTargetExistsButShouldNotMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" exists but should not. Change required.
NamespaceTargetDoesNotExistButShouldMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" does not exist but should. Change required.
NamespaceDoesNotExistAndShouldNotMessage=DFS Namespace "{0}" on "{1}.{2}" does not exists and should not. Change not required.
NamespaceTargetDoesNotExistAndShouldNotMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" does not exist and should not. Change not required.
'@
}

function Get-TargetResource 
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [String]
        $Namespace,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,
        
        [String]
        $ComputerName = ($ENV:COMPUTERNAME),

        [String]
        $DomainName       
    )       

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.GettingNamespaceMessage) `
                -f $Namespace,$ComputerName,$DomainName 
        ) -join '' )

    # Generate the return object assuming absent.
    $ReturnValue = @{
        Namespace = $Namespace
        Ensure = 'Absent'
        ComputerName = $ComputerName
        DomainName = $DomainName
    }
    
    # Remove the Ensue parmeter from the bound parameters
    $null = $PSBoundParameters.Remove('Ensure')
    
    # Get the namespace path and target path for this namespace target
    $NamespacePath = Get-NamespacePath @PSBoundParameters
    $TargetPath = Get-TargetPath @PSBoundParameters
    
    # Lookup the existing Namespace root    
    $Root = Get-Root `
        -Path $NamespacePath
    
    if ($Root)
    {
        # The namespace exists
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceExistsMessage) `
                    -f $Namespace,$ComputerName,$DomainName 
            ) -join '' )
    }
    else
    {
        # The namespace does not exist
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceDoesNotExistMessage) `
                    -f $Namespace,$ComputerName,$DomainName 
            ) -join '' )
        return $ReturnValue
    }

    $ReturnValue += @{
        Path                         = $Root.Path
        Type                         = $Root.Type
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
        -Path $NamespacePath `
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
                $($LocalizedData.NamespaceTargetExistsMessage) `
                    -f $Namespace,$ComputerName,$DomainName,$TargetPath 
            ) -join '' )
    }
    else
    {               
        # The target does not exist in this namespace
        Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceTargetDoesNotExistMessage) `
                    -f $Namespace,$ComputerName,$DomainName,$TargetPath
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
        $Namespace,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,
        
        [String]
        $ComputerName = ($ENV:COMPUTERNAME),

        [String]
        $DomainName,

        [String]
        $Description,
        
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

        [ValidateSet('GlobalHigh','SiteCostHigh','SiteCostNormal','SiteCostLow','GlobalLow')]
        [String]
        $ReferralPriorityClass,
        
        [Uint32]
        $ReferralPriorityRank        
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceMessage) `
                -f $Namespace,$ComputerName,$DomainName 
        ) -join '' )

    # Create splat for passing to get-* functions
    $Splat = @{
        Namespace = $Namespace
        ComputerName = $ComputerName
        DomainName = $DomainName
    }
    
    # Get the namespace path and target path for this namespace target
    $NamespacePath = Get-NamespacePath @Splat
    $TargetPath = Get-TargetPath @Splat

    # Lookup the existing Namespace root    
    $Root = Get-Root `
        -Path $NamespacePath

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

            if (($EnableSiteCosting -ne $null) `
                -and (($Root.Flags -contains 'Site Costing') -ne $EnableSiteCosting))
            {
                $RootProperties += @{                    
                    EnableSiteCosting = $EnableSiteCosting
                }
                $RootChange = $true
            }

            if (($EnableInsiteReferrals -ne $null) `
                -and (($Root.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals))
            {
                $RootProperties += @{                    
                    EnableInsiteReferrals = $EnableInsiteReferrals
                }
                $RootChange = $true
            }

            if (($EnableAccessBasedEnumeration -ne $null) `
                -and (($Root.Flags -contains 'AccessBased Enumeration') -ne $EnableAccessBasedEnumeration))
            {
                $RootProperties += @{                    
                    EnableAccessBasedEnumeration = $EnableAccessBasedEnumeration
                }
                $RootChange = $true
            }

            if (($EnableRootScalability -ne $null) `
                -and (($Root.Flags -contains 'Root Scalability') -ne $EnableRootScalability))
            {
                $RootProperties += @{                    
                    EnableRootScalability = $EnableRootScalability
                }
                $RootChange = $true
            }

            if (($EnableTargetFailback -ne $null) `
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
                    -Path $NamespacePath `
                    @RootProperties `
                    -ErrorAction Stop

                $RootProperties.GetEnumerator() | ForEach-Object -Process {                
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceUpdateParameterMessage) `
                            -f $Namespace,$ComputerName,$DomainName,$_.name, $_.value
                    ) -join '' )            
                }
            }
                                
            # Get target
            $Target = Get-RootTarget `
                -Path $NamespacePath `
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
                    ReferralPriorityClass = $ReferralPriorityClass
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
                        -Path $NamespacePath `
                        -TargetPath $TargetPath `
                        @TargetProperties `
                        -ErrorAction Stop
                }
            }
            else
            {
                # Add target to Namespace
                $null = New-DfsnRootTarget `
                    -Path $NamespacePath `
                    -TargetPath $TargetPath `
                    @TargetProperties `
                    -ErrorAction Stop
            }

            # Output the target parameters that were changed/set
            $TargetProperties.GetEnumerator() | ForEach-Object -Process {                
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceUpdateParameterMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$_.name, $_.value
                ) -join '' )            
            }            
        }
        else
        {
            # Prepare to use the PSBoundParameters as a splat to created
            # The new DFS Namespace root.
            $null = $PSBoundParameters.Remove('Namespace')
            $null = $PSBoundParameters.Remove('Ensure')
            $null = $PSBoundParameters.Remove('ComputerName')
            $null = $PSBoundParameters.Remove('DomainName')
            
            $PSBoundParameters += @{
                Type = 'Standalone'
                TargetPath  = $TargetPath
            }

            if ($DomainName)
            {
                $PSBoundParameters.Type = 'DomainV2'
            }

            if (! $Description)
            {
                $PSBoundParameters += @{ Description = "DFS of Namespace $Namespace" }
            }                    

            # Create New-DfsnRoot
            $null = New-DfsnRoot `
                @PSBoundParameters `
                -ErrorAction Stop
                                    
            $PSBoundParameters.GetEnumerator() | ForEach-Object -Process {                
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceUpdateParameterMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$_.name, $_.value
                ) -join '' )            
            }
        }
    }
    else
    {
        # The Namespace Target should not exist

        # Get root target
        $Target = Get-RootTarget `
            -Path $NamespacePath `
            -TargetPath $TargetPath
            
        if ($Target)                
        {
            # Remove the target from the namespace
            $null = Remove-DfsnRootTarget `
                -Path $NamespacePath `
                -TargetPath $TargetPath `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                $($LocalizedData.NamespaceTargetRemovedMessage) `
                    -f $Namespace,$ComputerName,$DomainName,$TargetPath
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
        $Namespace,

        [parameter(Mandatory = $true)]
        [ValidateSet('Present','Absent')]
        [String]
        $Ensure,
        
        [String]
        $ComputerName = ($ENV:COMPUTERNAME),

        [String]
        $DomainName,
        
        [String]
        $Description,

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

        [ValidateSet('GlobalHigh','SiteCostHigh','SiteCostNormal','SiteCostLow','GlobalLow')]
        [String]
        $ReferralPriorityClass,
        
        [Uint32]
        $ReferralPriorityRank          
    )
   
    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceMessage) `
                -f $Namespace,$ComputerName,$DomainName 
        ) -join '' )

    # Flag to signal whether settings are correct
    [Boolean] $DesiredConfigurationMatch = $true    

    # Create splat for passing to get-* functions
    $Splat = @{
        Namespace = $Namespace
        ComputerName = $ComputerName
        DomainName = $DomainName
    }

    # Get the namespace path and target path for this namespace target
    $NamespacePath = Get-NamespacePath @Splat
    $TargetPath = Get-TargetPath @Splat

    # Lookup the existing Namespace root    
    $Root = Get-Root `
        -Path $NamespacePath
            
    if ($Ensure -eq 'Present')
    {
        # The Namespace root should exist
        if ($Root)
        {
            # The Namespace root exists and should

            # Changing the namespace type is not possible - the namespace
            # can only be recreated if the type should change.
            if ((($DomainName) -and ($Root.Type -notmatch 'Domain')) -or `
                 ((! $DomainName) -and ($Root.Type -notmatch 'Standalone')))
            {                    
                if ($Root.Type -eq 'Standalone')
                {
                    $NewType = 'Domain'
                }
                else
                {
                    $NewType = 'Standalone'
                }
                $ErrorParam = @{
                    ErrorId = 'NamespaceTypeConversionError'
                    ErrorMessage = $($LocalizedData.NamespaceTypeConversionError) `
                        -f $Namespace,$ComputerName,$DomainName,$NewType
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
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'Description'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
                        
            if (($EnableSiteCosting -ne $null) `
                -and (($Root.Flags -contains 'Site Costing') -ne $EnableSiteCosting)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'EnableSiteCosting'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnableInsiteReferrals -ne $null) `
                -and (($Root.Flags -contains 'Insite Referrals') -ne $EnableInsiteReferrals)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'EnableInsiteReferrals'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnableAccessBasedEnumeration -ne $null) `
                -and (($Root.Flags -contains 'AccessBased Enumeration') -ne $EnableAccessBasedEnumeration)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'EnableAccessBasedEnumeration'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnableRootScalability -ne $null) `
                -and (($Root.Flags -contains 'Root Scalability') -ne $EnableRootScalability)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'EnableRootScalability'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            if (($EnableTargetFailback -ne $null) `
                -and (($Root.Flags -contains 'Target Failback') -ne $EnableTargetFailback)) {
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                        -f $Namespace,$ComputerName,$DomainName,'EnableTargetFailback'
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }

            $Target = Get-RootTarget `
                -Path $NamespacePath `
                -TargetPath $TargetPath

            if ($Target)
            {
                if (($ReferralPriorityClass) `
                    -and ($Target.ReferralPriorityClass -ne $ReferralPriorityClass)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                            -f $Namespace,$ComputerName,$DomainName,'ReferralPriorityClass'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }

                if (($ReferralPriorityRank) `
                    -and ($Target.ReferralPriorityRank -ne $ReferralPriorityRank)) {
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceParameterNeedsUpdateMessage) `
                            -f $Namespace,$ComputerName,$DomainName,'ReferralPriorityRank'
                        ) -join '' )
                    $desiredConfigurationMatch = $false
                }
            }
            else
            {
                # The Root target does not exist but should - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceTargetDoesNotExistButShouldMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false                   
            }
        }
        else
        {
            # Ths Namespace root doesn't exist but should - change required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceDoesNotExistButShouldMessage) `
                    -f $Namespace,$ComputerName,$DomainName
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
                -Path $NamespacePath `
                -TargetPath $TargetPath
                
            if ($Target)
            {
                # The Root target exists but should not - change required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceTargetExistsButShouldNotMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$TargetPath
                    ) -join '' )
                $desiredConfigurationMatch = $false
            }
            else
            {
                # The Namespace exists but the target doesn't - change not required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceTargetDoesNotExistAndShouldNotMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$TargetPath
                    ) -join '' )
            }
        }
        else
        {
            # The Namespace does not exist (so neither does the target) - change not required
            Write-Verbose -Message ( @(
                "$($MyInvocation.MyCommand): "
                 $($LocalizedData.NamespaceDoesNotExistAndShouldNotMessage) `
                    -f $Namespace,$ComputerName,$DomainName
                ) -join '' )
        }
    } # if
               
    return $DesiredConfigurationMatch 

} # Test-TargetResource

# Helper Functions
Function Get-NamespacePath {
    param
    (
        [String]
        $Namespace,

        [String]
        $ComputerName,

        [String]
        $DomainName
    )       
    # Determine the Namespace Path.
    if ($DomainName)
    {
        $DFSRootName = $DomainName
    }
    else 
    {
        $DFSRootName = $ComputerName.ToUpper()
    }
    return "\\$DFSRootName\$Namespace"
}

Function Get-TargetPath {
    param
    (
        [String]
        $Namespace,

        [String]
        $ComputerName,

        [String]
        $DomainName
    )       
    # Determine the Target Path.
    return "\\$($ComputerName.ToUpper())\$Namespace"
}

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
        $Target = Get-DfsnRootTarget `
            -Path $Path `
            -TargetPath $TargetPath `
            -ErrorAction Stop
        $Target.ReferralClass = ($Target.ReferralClass -replace '-','')
    }
    catch [Microsoft.Management.Infrastructure.CimException]
    {
        $Target = $null
    }
    catch
    {
        Throw $_
    }
    Return $Target
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

