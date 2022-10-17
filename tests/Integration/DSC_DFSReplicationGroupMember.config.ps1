Configuration DSC_DFSReplicationGroupMember_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSReplicationGroupMember Integration_Test {
            GroupName               = $Node.GroupName
            ComputerName            = $Node.ComputerName
            Ensure                  = $Node.Ensure
            PSDSCRunAsCredential    = $Node.PSDSCRunAsCredential
        }
    }
}
