#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

server="${Server-$TEST_XENSERVER}"
echo "Running on $server."

remote_execute "root@$server" \
               "$thisdir/reboot/test_reboot.sh"
