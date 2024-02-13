Configuration DSC_DFSNamespaceRoot_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSNamespaceRoot Integration_Test {
            Path                         = $Node.Path
            TargetPath                   = $Node.TargetPath
            Ensure                       = $Node.Ensure
            TargetState                  = $Node.TargetState
            Type                         = $Node.Type
            Description                  = $Node.Description
            TimeToLiveSec                = $Node.TimeToLiveSec
            EnableSiteCosting            = $Node.EnableSiteCosting
            EnableInsiteReferrals        = $Node.EnableInsiteReferrals
            EnableAccessBasedEnumeration = $Node.EnableAccessBasedEnumeration
            # Not supported by Standalone Namespaces
            # EnableRootScalability        = $Node.EnableRootScalability
            EnableTargetFailback         = $Node.EnableTargetFailback
            ReferralPriorityClass        = $Node.ReferralPriorityClass
            ReferralPriorityRank         = $Node.ReferralPriorityRank
            State                        = $Node.State
        }
    }
}
