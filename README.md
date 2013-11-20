# Top level

 - `install-devstack-xen.sh`: All-in-one script to install devstack in a domU
   on XenServer/XCP or other Xapi toolstack server
 - `xenserver-quantum-devstack.sh`: All-in-one script to set up xenserver with
   quantum.

# `jenkins` Directory
Scripts that are useful for Jenkins jobs:

 - [Jobs](./jenkins/jobs/README.md)
 - Running tests
 - Manage repositories
 - Provide locking

# Branch management

## Create a ref on build pointing to the latest master

    ./update-workspace-to-origin-master.sh
    ./push-ref-to-build.sh refs/citrix-builds/test1

## Cherry-pick one change on top of the latest master and push it as a ref

    ./update-workspace-to-origin-master.sh
    echo "openstack-dev/devstack refs/changes/60/39360/2" |
      ./cherry-pick-changes-to-workspace-from-stdin.sh

    ./push-ref-to-build.sh refs/citrix-builds/test2

## See the difference between two references

    ./with-all-repos-in-workspace.sh \
      git diff refs/citrix-builds/test1..refs/citrix-builds/test2

## If a new repo comes

 - amend `lib/functions`
 - execute `create_repos.sh`
 - amend puppet maifests
 - kick puppet
