#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

server="${Server-$TEST_XENSERVER}"

rm -f "$thisdir/os-vpx-bugtool-"*.tar.bz2

remote_execute "root@$server" "$thisdir/bugtool/bugtool_test.sh" \
               "$build_url" "citrix"

link=$(ssh "root@$server" readlink -f /tmp/outgoing-bugtool || true)

if [ "$link" ]
then
  scp "root@$server:$link" "$thisdir"
fi
