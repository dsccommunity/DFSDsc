$NamespaceServerConfiguration = @{
    LdapTimeoutSec               = 45
    SyncIntervalSec              = 5000
    UseFQDN                      = $True
}

Configuration MSFT_xDFSNamespaceServerConfiguration_Config {
    Import-DscResource -ModuleName xDFS
    node localhost {
        xDFSNamespaceServerConfiguration Integration_Test {
            IsSingleInstance             = 'Yes'
            LdapTimeoutSec               = $NamespaceServerConfiguration.LdapTimeoutSec
            SyncIntervalSec              = $NamespaceServerConfiguration.SyncIntervalSec
            UseFQDN                      = $NamespaceServerConfiguration.UseFQDN
        }
    }
}
