Configuration DSC_DFSNamespaceFolder_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSNamespaceFolder Integration_Test {
            Path                         = $Node.Path
            TargetPath                   = $Node.TargetPath
            Ensure                       = $Node.Ensure
            TargetState                  = $Node.TargetState
            Description                  = $Node.Description
            EnableInsiteReferrals        = $Node.EnableInsiteReferrals
            EnableTargetFailback         = $Node.EnableTargetFailback
            ReferralPriorityClass        = $Node.ReferralPriorityClass
            ReferralPriorityRank         = $Node.ReferralPriorityRank
            State                        = $Node.State
        }
    }
}
