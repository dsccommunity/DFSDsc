Configuration DSC_DFSReplicationGroupMembership_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSReplicationGroupMembership Integration_Test {
            GroupName            = $Node.GroupName
            FolderName           = $Node.FolderName
            ComputerName         = $Node.ComputerName
            ContentPath          = $Node.ContentPath
            ReadOnly             = $Node.ReadOnly
            PrimaryMember        = $Node.PrimaryMember
            PSDSCRunAsCredential = $Node.PSDSCRunAsCredential
        }
    }
}
