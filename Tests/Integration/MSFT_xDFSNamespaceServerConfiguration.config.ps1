$NamespaceServerConfiguration = @{
    LdapTimeoutSec               = 45
    EnableInsiteReferrals        = $True
    EnableSiteCostedReferrals    = $True
    PreferLogonDC                = $True
    SyncIntervalSec              = 20
    UseFQDN                      = $True
}

Configuration MSFT_xDFSNamespaceServerConfiguration_Config {
    Import-DscResource -ModuleName xDFS
    node localhost {
        xDFSNamespaceRoot Integration_Test {
            IsSingleInstance             = 'Yes'
            LdapTimeoutSec               = $NamespaceServerConfiguration.LdapTimeoutSec
            EnableInsiteReferrals        = $NamespaceServerConfiguration.EnableInsiteReferrals
            EnableSiteCostedReferrals    = $NamespaceServerConfiguration.EnableSiteCostedReferrals
            PreferLogonDC                = $NamespaceServerConfiguration.PreferLogonDC
            SyncIntervalSec              = $NamespaceServerConfiguration.SyncIntervalSec
            UseFQDN                      = $NamespaceServerConfiguration.UseFQDN
        }
    }
}
