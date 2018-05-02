$NamespaceRootName = 'IntegrationTestNamespace'
$NamespaceRoot = @{
    Path                         = "\\$($env:COMPUTERNAME)\$NamespaceRootName"
    TargetPath                   = "\\$($env:COMPUTERNAME)\$NamespaceRootName"
    Ensure                       = 'Present'
    Type                         = 'Standalone'
    Description                  = 'Integration test namespace'
    TimeToLiveSec                = 500
    EnableSiteCosting            = $true
    EnableInsiteReferrals        = $true
    EnableAccessBasedEnumeration = $true
    EnableRootScalability        = $true
    EnableTargetFailback         = $true
    ReferralPriorityClass        = 'Global-Low'
    ReferralPriorityRank         = 10
}

Configuration MSFT_DFSNamespaceRoot_Config {
    Import-DscResource -ModuleName DFSDsc
    node localhost {
        DFSNamespaceRoot Integration_Test {
            Path                         = $NamespaceRoot.Path
            TargetPath                   = $NamespaceRoot.TargetPath
            Ensure                       = $NamespaceRoot.Ensure
            Type                         = $NamespaceRoot.Type
            Description                  = $NamespaceRoot.Description
            TimeToLiveSec                = $NamespaceRoot.TimeToLiveSec
            EnableSiteCosting            = $NamespaceRoot.EnableSiteCosting
            EnableInsiteReferrals        = $NamespaceRoot.EnableInsiteReferrals
            EnableAccessBasedEnumeration = $NamespaceRoot.EnableAccessBasedEnumeration
            # Not supported by Standalone Namespaces
            # EnableRootScalability        = $NamespaceRoot.EnableRootScalability
            EnableTargetFailback         = $NamespaceRoot.EnableTargetFailback
            ReferralPriorityClass        = $NamespaceRoot.ReferralPriorityClass
            ReferralPriorityRank         = $NamespaceRoot.ReferralPriorityRank
        }
    }
}
