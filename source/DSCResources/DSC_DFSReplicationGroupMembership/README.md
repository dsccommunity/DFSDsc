# Description

This resource is used to configure Replication Group Folder Membership. It is
usually used to set the **ContentPath** for each Replication Group folder on each
Member computer. It can also be used to set additional properties of the Membership.
This resource shouldn't be used for folders where the Content Path is set in the
DFSReplicationGroup.

> Note: The PrimaryMember flag is automatically cleared by DFS once an initial
> replication sync takes place, so is not tested by this resource.
