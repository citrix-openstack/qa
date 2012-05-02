#!/bin/bash

set -eux

RunExercises=$1
RunTempest=$2
DevStackURL=$3
LocalrcURL=$4
PreseedURL=$5
GuestIp=$6

# tidy up the scripts we copied over on exit
SCRIPT_TMP_DIR=/tmp/jenkins_test
cd $SCRIPT_TMP_DIR

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

if [ "$GuestIp" != "false" ]
then
    cat <<EOF >>localrc
# appended by jenkins
MASTER_SERVER=$GuestIp
ENABLED_SERVICES=n-cpu,n-net,n-api
MYSQL_HOST=$MASTER_SERVER
RABBIT_HOST=$MASTER_SERVER
KEYSTONE_AUTH_HOST=$MASTER_SERVER
GLANCE_HOSTPORT=$MASTER_SERVER:9292
EOF
fi

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
    GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
    OPENSTACK_GUEST_IP=$(xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$OPENSTACK_GUEST_IP" \ "~/devstack/exercise.sh"

    if $RunTempest
    then
        scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SCRIPT_TMP_DIR/run-tempest.sh" "stack@$OPENSTACK_GUEST_IP:~/"
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$OPENSTACK_GUEST_IP" \ "~/run-tempest.sh"
    fi
fi

echo "on-host exiting"
