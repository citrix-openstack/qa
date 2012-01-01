#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

add_on_exit "rm -rf /func-multinic-test/*"

server="${Server-$TEST_XENSERVER}"
echo "Running on $server."

scp $thisdir/multinic/test-xs-multinic.sh root@$server:~/

remote_execute "root@$server" \
               "$thisdir/multinic/multinic_test_wrapper.sh"
