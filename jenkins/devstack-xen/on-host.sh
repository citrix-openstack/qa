#!/bin/bash

set -eux

RunExercises=$1
RunTempest=$2
DevStackURL=$3
LocalrcURL=$4
PreseedURL=$5

# tidy up the scripts we copied over on exit
SCRIPT_TMP_DIR=/tmp/jenkins_test
cd $SCRIPT_TMP_DIR

# import the common utils
. "$SCRIPT_TMP_DIR/common.sh"
. "$SCRIPT_TMP_DIR/common-ssh.sh"

#
# Download DevStack
#
wget --output-document=devstack.zip --no-check-certificate $DevStackURL
unzip -o devstack.zip -d ./devstack
cd devstack/*/

#
# Download localrc
#
wget --output-document=localrc --no-check-certificate $LocalrcURL

cd tools/xen

#
# Download preseed
#
rm devstackubuntupreseed.cfg
wget --output-document=devstackubuntupreseed.cfg --no-check-certificate $PreseedURL

#
# Install VM
#
./install_os_domU.sh

#
# Run some tests to make sure everything is working
#
if $RunExercises
then
    ssh_no_hosts "stack@$OPENSTACK_GUEST_IP" \ "~/devstack/exercise.sh"
fi

if $RunTempest
then
    scp_no_hosts "$SCRIPT_TMP_DIR/run-tempest.sh" "stack@$OPENSTACK_GUEST_IP:~/"
    ssh_no_hosts  "stack@$OPENSTACK_GUEST_IP" \ "~/run-tempest.sh"
fi

echo "on-host exiting"
