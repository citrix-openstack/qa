#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

sudo su -c "$thisdir/run-devstack-helper.sh" root

stackdir=/tmp/stack
cd $stackdir/devstack/tools/xen
mv stage /tmp
cd ../../../
scp -r devstack root@$server:~/
mv /tmp/stage $stackdir/devstack/tools/xen

remote_execute "root@$server" \
        "$thisdir/devstack/on-host.sh"
