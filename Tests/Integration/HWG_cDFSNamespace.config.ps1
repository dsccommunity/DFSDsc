$Namespace = @{
    Namespace                    = 'IntegrationTestNamespace' 
    ComputerName                 = $ENV:ComputerName
    Ensure                       = 'Present'
    Description                  = 'Integration test namespace'
    EnableSiteCosting            = $true
    EnableInsiteReferrals        = $true
    EnableAccessBasedEnumeration = $true
    EnableRootScalability        = $true
    EnableTargetFailback         = $true
    ReferralPriorityClass        = 'GlobalLow'
    ReferralPriorityRank         = 10
}
$NamespacePath = "\\$($Namespace.ComputerName.ToUpper())\$($Namespace.Namespace)"
$TargetPath = "\\$($Namespace.ComputerName.ToUpper())\$($Namespace.Namespace)"

Configuration HWG_cDFSNamespace_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSNamespace Integration_Test {
            Namespace                    = $Namespace.Namespace 
            ComputerName                 = $Namespace.ComputerName
            Ensure                       = $Namespace.Ensure
            Description                  = $Namespace.Description
            EnableSiteCosting            = $Namespace.EnableSiteCosting
            EnableInsiteReferrals        = $Namespace.EnableInsiteReferrals
            EnableAccessBasedEnumeration = $Namespace.EnableAccessBasedEnumeration
            EnableRootScalability        = $Namespace.EnableRootScalability
            EnableTargetFailback         = $Namespace.EnableTargetFailback
            ReferralPriorityClass        = $Namespace.ReferralPriorityClass
            ReferralPriorityRank         = $Namespace.ReferralPriorityRank
        }
    }
}
