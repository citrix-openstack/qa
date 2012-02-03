#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"
enter_jenkins_test

server="${Server-$TEST_XENSERVER}"

stackdir="/tmp/stack"
if $CleanStackDir
then
    rm -rf $stackdir
fi
mkdir -p $stackdir
cd $stackdir

if [ ! -d $stackdir/devstack ]
then
    git clone git@github.com:renuka-apte/devstack.git
fi

#
# Get latest devstack
# And build the XVA
# **as root**
#
if $AptProxy
then
    scaptproxy=yes
else
    scaptproxy=no
fi
sudo su -c "server=$server scaptproxy=$scaptproxy stackdir=$stackdir $thisdir/run-devstack-helper.sh" root

#
# Copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test

cd $stackdir/devstack/tools/xen
sudo mv stage /tmp
cd ../../../
scp -r devstack root@$server:$SCRIPT_TMP_DIR
sudo mv /tmp/stage $stackdir/devstack/tools/xen

scp $thisdir/common.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/common-xe.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/common-ssh.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/verify.sh root@$server:$SCRIPT_TMP_DIR
scp $thisdir/devstack/run-excercise.sh root@$server:$SCRIPT_TMP_DIR

#
# Run the next steps on the XenServer
#
remote_execute "root@$server" "$thisdir/devstack/on-host.sh"

echo "devstack exiting"
