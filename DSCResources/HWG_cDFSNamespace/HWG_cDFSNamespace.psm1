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
NamespaceTargetExistsAndShouldMessage=DFS Namespace "{0}" target "{3}" on "{1}.{2}" exists and should. Change not required.
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
        Path          = $Root.Path
        Type          = $Root.Type
        TimeToLiveSec = $Root.TimeToLiveSec
        State         = $Root.State
        Description   = $Root.Description
    }
    
    # DFS Root exists but does target exist?               
    $Target = Get-RootTarget `
        -Path $NamespacePath `
        -TargetPath $TargetPath

    if ($Target)
    {
        # The target exists in this namespace
        $ReturnValue.Ensure = 'Present'

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
        $Description
    )

    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.SettingNamespaceMessage) `
                -f $Namespace,$ComputerName,$DomainName 
        ) -join '' )

    # Remove parameters that can't be splatted
    $null = $PSBoundParameters.Remove('Ensure')
    $null = $PSBoundParameters.Remove('Description')
    
    # Get the namespace path and target path for this namespace target
    $NamespacePath = Get-NamespacePath @PSBoundParameters
    $TargetPath = Get-TargetPath @PSBoundParameters

    # Lookup the existing Namespace root    
    $Root = Get-Root `
        -Path $NamespacePath

    if ($Ensure -eq 'Present')
    {
        # Set desired Configuration
        $NewRoot = @{
            Path = $NamespacePath
            State = 'online'
        }

        if ($Root)
        {
            [boolean] $RootChange = $false
            
            if (($Description) `
                -and ($Root.Description -ne $Description))
            {
                $NewRoot += @{                    
                    Description = $Description
                }
                $RootChange = $true
            }

            if ($RootChange)
            {
                # Reset settings
                $null = Set-DfsnRoot `
                    @NewRoot `
                    -ErrorAction Stop

                $NewRoot.GetEnumerator() | ForEach-Object -Process {                
                    Write-Verbose -Message ( @(
                        "$($MyInvocation.MyCommand): "
                        $($LocalizedData.NamespaceUpdateParameterMessage) `
                            -f $Namespace,$ComputerName,$DomainName,$_.name, $_.value
                    ) -join '' )            
                }
            }
                                
            # Get root target
            $Target = Get-RootTarget `
                -Path $NamespacePath `
                -TargetPath $TargetPath
            
            # Is the target a member of the namespace?
            if (! $Target)
            {
                # Add target to Namespace
                $null = New-DfsnRootTarget `
                    -Path $NamespacePath `
                    -TargetPath $TargetPath `
                    -ErrorAction Stop
            }
        }
        else
        {
            # Add additional information
            $NewRoot += @{
                Type = 'Standalone'
                TargetPath  = $TargetPath
                Description = "DFS of Namespace $Namespace"
            }

            if ($DomainName)
            {
                $NewRoot.Type = 'DomainV2'
            }

            if ($Description)
            {
                $NewRoot.Description = $Description
            }                    

            # Create New-DfsnRoot
            $null = New-DfsnRoot `
                @NewRoot `
                -ErrorAction Stop
                                    
            $NewRoot.GetEnumerator() | ForEach-Object -Process {                
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
        $Description
    )
   
    Write-Verbose -Message ( @(
            "$($MyInvocation.MyCommand): "
            $($LocalizedData.TestingNamespaceMessage) `
                -f $Namespace,$ComputerName,$DomainName 
        ) -join '' )

    # Flag to signal whether settings are correct
    [Boolean] $DesiredConfigurationMatch = $true    

    # Remove parameters that can't be splatted
    $null = $PSBoundParameters.Remove('Ensure')
    $null = $PSBoundParameters.Remove('Description')

    # Get the namespace path and target path for this namespace target
    $NamespacePath = Get-NamespacePath @PSBoundParameters
    $TargetPath = Get-TargetPath @PSBoundParameters

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
                        
            $Target = Get-RootTarget `
                -Path $NamespacePath `
                -TargetPath $TargetPath

            if ($Target)
            {
                # The Root target exists - change not required
                Write-Verbose -Message ( @(
                    "$($MyInvocation.MyCommand): "
                    $($LocalizedData.NamespaceTargetExistsAndShouldMessage) `
                        -f $Namespace,$ComputerName,$DomainName,$TargetPath
                    ) -join '' )
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

