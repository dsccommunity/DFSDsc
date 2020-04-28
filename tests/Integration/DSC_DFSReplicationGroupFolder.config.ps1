Configuration DSC_DFSReplicationGroupFolder_Config {
    Import-DscResource -ModuleName DFSDsc

    Node localhost {
        DFSReplicationGroupFolder Integration_Test {
            GroupName              = $Node.GroupName
            FolderName             = $Node.FolderName
            Description            = $Node.Description
            DirectoryNameToExclude = $Node.DirectoryNameToExclude
            FilenameToExclude      = $Node.FilenameToExclude
            PSDSCRunAsCredential   = $Node.PSDSCRunAsCredential
        }
    }
}
