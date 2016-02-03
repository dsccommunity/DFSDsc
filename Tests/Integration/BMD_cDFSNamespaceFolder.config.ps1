$NamespaceRootName = 'IntegrationTestNamespace'
$NamespaceFolderName = 'TestFolder'
$NamespaceRoot = @{
    Path                         = "\\$($ENV:ComputerName)\$NamespaceRootName"
    TargetPath                   = "\\$($ENV:ComputerName)\$NamespaceRootName"
}
$NamespaceFolder = @{
    Path                         = "$($NamespaceRoot.Path)\$NamespaceFolderName"
    TargetPath                   = "\\$($ENV:ComputerName)\$NamespaceFolderName"
    Ensure                       = 'Present'
    Description                  = 'Integration test namespace folder'
    EnableInsiteReferrals        = $true
    EnableTargetFailback         = $true
    ReferralPriorityClass        = 'Global-Low'
    ReferralPriorityRank         = 10
}

Configuration BMD_cDFSNamespaceFolder_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSNamespaceFolder Integration_Test {
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
