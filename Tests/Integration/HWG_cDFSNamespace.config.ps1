$Namespace = @{
    Namespace            = 'IntegrationTestNamespace' 
    ComputerName         = $ENV:ComputerName
    Ensure               = 'Present'
    Description          = 'Integration test namespace'
}
$NamespacePath = "\\$($Namespace.ComputerName.ToUpper())\$($Namespace.Namespace)"

Configuration HWG_cDFSNamespace_Config {
    Import-DscResource -ModuleName cDFS
    node localhost {
        cDFSNamespace Integration_Test {
            Namespace            = $Namespace.Namespace 
            ComputerName         = $Namespace.ComputerName
            Ensure               = $Namespace.Ensure
            Description          = $Namespace.Description
        }
    }
}
