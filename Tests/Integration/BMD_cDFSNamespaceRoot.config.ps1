$NamespaceName = 'IntegrationTestNamespace'
$Namespace = @{
    Path                         = "\\$($ENV:ComputerName)\$NamespaceName"
    TargetPath                   = "\\$($ENV:ComputerName)\$NamespaceName" 
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
            Path                         = $Namespace.Path 
            TargetPath                   = $Namespace.TargetPath
            Ensure                       = $Namespace.Ensure
            Type                         = $Namespace.Type
            Description                  = $Namespace.Description
            EnableSiteCosting            = $Namespace.EnableSiteCosting
            EnableInsiteReferrals        = $Namespace.EnableInsiteReferrals
            EnableAccessBasedEnumeration = $Namespace.EnableAccessBasedEnumeration
            # Not supported by Standalone Namespaces
            # EnableRootScalability        = $Namespace.EnableRootScalability
            EnableTargetFailback         = $Namespace.EnableTargetFailback
            ReferralPriorityClass        = $Namespace.ReferralPriorityClass
            ReferralPriorityRank         = $Namespace.ReferralPriorityRank
        }
    }
}
