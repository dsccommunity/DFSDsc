$NamespaceRootName = 'IntegrationTestNamespace'
$NamespaceFolderName = 'TestFolder'
$NamespaceRoot = @{
    Path                         = "\\$($env:COMPUTERNAME)\$NamespaceRootName"
    TargetPath                   = "\\$($env:COMPUTERNAME)\$NamespaceRootName"
}
$NamespaceFolder = @{
    Path                         = "$($NamespaceRoot.Path)\$NamespaceFolderName"
    TargetPath                   = "\\$($env:COMPUTERNAME)\$NamespaceFolderName"
    Ensure                       = 'Present'
    Description                  = 'Integration test namespace folder'
    EnableInsiteReferrals        = $true
    EnableTargetFailback         = $true
    ReferralPriorityClass        = 'Global-Low'
    ReferralPriorityRank         = 10
}

Configuration MSFT_DFSNamespaceFolder_Config {
    Import-DscResource -ModuleName DFSDsc
    node localhost {
        DFSNamespaceFolder Integration_Test {
            Path                         = $NamespaceFolder.Path
            TargetPath                   = $NamespaceFolder.TargetPath
            Ensure                       = $NamespaceFolder.Ensure
            Description                  = $NamespaceFolder.Description
            EnableInsiteReferrals        = $NamespaceFolder.EnableInsiteReferrals
            EnableTargetFailback         = $NamespaceFolder.EnableTargetFailback
            ReferralPriorityClass        = $NamespaceFolder.ReferralPriorityClass
            ReferralPriorityRank         = $NamespaceFolder.ReferralPriorityRank
        }
    }
}
