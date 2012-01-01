#!/bin/bash

set -eux
net_mode="${NetworkingMode-flat}" # can be flat, flatdhcp, vlan, flatdhcp-ha

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

add_on_exit "rm -rf /func-floatingip-test/*"

if [ "$net_mode" != "flat" ]
then
    server="${Server-$TEST_XENSERVER_2}"
else
    server="${Server-$TEST_XENSERVER}"
fi

echo "Running on $server."
if [ $net_mode == "flat" ]
then
    echo "Skipping the test."
else
    scp $thisdir/floating-ips/test-floatingip.sh root@$server:~/

    remote_execute "root@$server" \
               "$thisdir/floating-ips/test_floatingip_wrapper.sh"
fi
