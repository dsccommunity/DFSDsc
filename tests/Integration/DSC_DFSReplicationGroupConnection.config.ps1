Configuration DSC_DFSReplicationGroupConnection_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSReplicationGroupConnection Integration_Test {
            GroupName               = $Node.GroupName
            Ensure                  = $Node.Ensure
            SourceComputerName      = $Node.SourceComputerName
            DestinationComputerName = $Node.DestinationComputerName
            PSDSCRunAsCredential    = $Node.PSDSCRunAsCredential
        }
    }
}
