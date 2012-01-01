#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

server="${Server-$TEST_XENSERVER}"

remote_execute "root@$server" \
               "$thisdir/uninstall/uninstall_test.sh" \
               "$build_url"
