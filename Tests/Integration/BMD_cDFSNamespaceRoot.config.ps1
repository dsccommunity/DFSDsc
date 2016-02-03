$NamespaceRootName = 'IntegrationTestNamespace'
$NamespaceRoot = @{
    Path                         = "\\$($ENV:ComputerName)\$NamespaceRootName"
    TargetPath                   = "\\$($ENV:ComputerName)\$NamespaceRootName" 
    Ensure                       = 'Present'
    Type                         = 'Standalone'
    Description                  = 'Integration test namespace'
    EnableSiteCosting            = $true
    EnableInsiteReferrals        = $true
    EnableAccessBasedEnumeration = $true
    EnableRootScalability        = $true
    EnableTargetFailback         = $true
    ReferralPriorityClass        = 'Global-Low'
    ReferralPriorityRank         = 10
}

Configuration BMD_cDFSNamespaceRoot_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSNamespaceRoot Integration_Test {
            Path                         = $NamespaceRoot.Path 
            TargetPath                   = $NamespaceRoot.TargetPath
            Ensure                       = $NamespaceRoot.Ensure
            Type                         = $NamespaceRoot.Type
            Description                  = $NamespaceRoot.Description
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
