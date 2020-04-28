Configuration DSC_DFSReplicationGroup_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSReplicationGroup Integration_Test {
            GroupName            = $Node.GroupName
            Description          = $Node.Description
            Ensure               = $Node.Ensure
            Members              = $Node.Members
            Folders              = $Node.Folders
            ContentPaths         = $Node.ContentPaths
            Topology             = $Node.Topology
            PSDSCRunAsCredential = $Node.PSDSCRunAsCredential
        }
    }
}
