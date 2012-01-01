#!/bin/bash

# Test that syslog is remoting to the VPX Master.

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

server="${Server-$TEST_XENSERVER}"

if [ "$#" -eq 1 ]
then
  server="$1"
fi

port=
master=$(remote_execute "root@$server" \
                          "$thisdir/utils/get_master_address.sh")
establish_tunnel $master 8080 $server port
master_url="http://localhost:$port"

password="citrix"

remote_execute "root@$server" "$thisdir/utils/os-vpx-scp.sh" \
		"$password" \
		"$master" \
		"/var/log/messages" \
		"/tmp/syslog"

add_on_exit "rm -rf /tmp/syslog"

nodes=$("$thisdir/utils/get-all-nodes" "$master_url")

remote_execute "root@$server" \
          "$thisdir/remote-syslog/check-node-entry.sh" "$nodes"
           
