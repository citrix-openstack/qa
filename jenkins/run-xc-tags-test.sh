#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

tags=
if [ "$#" -eq 0 ]
then
  server="${Server-$TEST_XENSERVER}"
  tags=$(remote_execute "root@$server" \
                        "$thisdir/xencenter-tags/get_vm_tags.sh")
elif [ "$#" -gt 0 ]
then
  # Let's assume that the server on which the Master VPX is on
  # is the first of the list of servers
  server="$1"
  for svr in $@
  do
    t="$(remote_execute "root@$svr" \
                        "$thisdir/xencenter-tags/get_vm_tags.sh")"
    tags="$t, $tags"
  done
fi

port=
master=$(remote_execute "root@$server" \
                          "$thisdir/utils/get_master_address.sh")
establish_tunnel $master 8080 $server port
master_url="http://localhost:$port"

"$thisdir/xencenter-tags/tags_roles_cmp" "$master_url" "$tags"
