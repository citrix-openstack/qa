#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

add_on_exit "rm -rf /func-volume-test/*"

server="${Server-$TEST_XENSERVER}"
echo "Running on $server."

scp $thisdir/volume/test-sm-volume.sh root@$server:~/
scp $thisdir/utils/set_globals root@$server:~/
scp $thisdir/utils/common.py root@$server:~/

remote_execute "root@$server" \
               "$thisdir/volume/volume_test_wrapper.sh"
