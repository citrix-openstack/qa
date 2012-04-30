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

# clean up after we are done
add_on_exit "rm -rf $SCRIPT_TMP_DIR"

#
# Download DevStack
#
wget --output-document=devstack.zip --no-check-certificate $DevStackURL
unzip -o devstack.zip -d ./devstack
cd devstack/*/

#
# Download localrc
#
wget --no-check-certificate $LocalrcURL

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
    scp_no_hosts "$SCRIPT_TMP_DIR/run-excercise.sh" "stack@$guestnode:~/"
    ssh_no_hosts  "stack@$guestnode" \ "~/run-excercise.sh"
fi

if $RunTempest
then
    scp_no_hosts "$SCRIPT_TMP_DIR/run-tempest.sh" "stack@$guestnode:~/"
    ssh_no_hosts  "stack@$guestnode" \ "~/run-tempest.sh"
fi

echo "on-host exiting"
