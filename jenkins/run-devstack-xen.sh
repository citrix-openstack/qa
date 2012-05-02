#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

#
# Get settings
#
server="${Server-"default_test_xenserver"}"

DefaultDevStackURL="https://github.com/openstack-dev/devstack/zipball/master"
DevStackURL="${DevStackURL-$DefaultDevStackURL}"

defaultlocalrc="http://gold.eng.hq.xensource.com/localrc"
localrcURL="${localrcURL-$defaultlocalrc}"

RunExercises="${RunExercises-false}"
RunTempest="${RunTempest-false}"

DefaultPreseedURL="http://gold.eng.hq.xensource.com/devstackubuntupreseed.cfg"
PreseedURL="${PreseedURL-$DefaultPreseedURL}"

GuestIP="${GUEST_IP-false}"

#
# Clean directory, create directory and
# copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test

ssh "$server" "rm -rf $SCRIPT_TMP_DIR"
ssh "$server" "mkdir -p $SCRIPT_TMP_DIR/devstack"

scp $thisdir/common.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/common-ssh.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/run-tempest.sh root@$server:$SCRIPT_TMP_DIR

#
# Run the next steps on the XenServer
#
remote_execute "root@$server" "$thisdir/devstack-xen/on-host.sh" "${RunExercises}" "${RunTempest}" "${DevStackURL}" "${localrcURL}" "${PreseedURL}" "${GuestIP}"

#
# Tidy up after running the test
#
ssh "$server" "rm -rf $SCRIPT_TMP_DIR"

#
# All done!
#
echo "Test complete"
