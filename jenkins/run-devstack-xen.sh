#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"
enter_jenkins_test

server="${Server-$TEST_XENSERVER}"

#
# Get settings
#
DefaultDevStackURL="https://github.com/openstack-dev/devstack/zipball/master"
DevStackURL="${DevStackURL-$DefaultDevStackURL}"

defaultlocalrc="http://gold.eng.hq.xensource.com/localrc"
localrcURL="${localrcURL-$defaultlocalrc}"

RunExercises="${RunExercises-true}"
RunTempest="${RunTempest-true}"

DefaultPreseedURL="http://gold.eng.hq.xensource.com/devstackubuntupreseed.cfg"
PreseedURL="${PreseedURL-$DefaultPreseedURL}"

#
# Copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test

ssh "$server" "rm -rf $SCRIPT_TMP_DIR"
ssh "$server" "mkdir -p $SCRIPT_TMP_DIR/devstack"

scp $thisdir/common.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/common-xe.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/common-ssh.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/verify.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/run-excercise.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/run-tempest.sh root@$server:$SCRIPT_TMP_DIR

#
# Run the next steps on the XenServer
#

remote_execute "root@$server" "$thisdir/devstack-xen/on-host.sh" "${RunExercises}" "${RunTempest}" "${DevStackURL}" "${localrcURL}" "${PreseedURL}"

echo "devstack exiting"
