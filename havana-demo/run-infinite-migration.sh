#!/bin/bash
set -eux

HOST_2="$1"

[ -n "$HOST_2" ]

DEVSTACK_2=$(ssh -q -o BatchMode=yes $HOST_2 bash -s -- << EOF
set -eux
wget -qO functions https://raw.github.com/openstack-dev/devstack/master/tools/xen/functions
. functions
find_ip_by_name DevStackOSDomU 0
EOF
)

set +x
cat << EOF

### HAVANA DEMO ###

Running two xenserver-core compute nodes with a webserver migrating back and
forth in an infinite loop.

The webserver is serving two video files:

http://$DEVSTACK_2:1235/the-xen-movie-android.mp4
http://$DEVSTACK_2:1235/the-xen-movie-iphone.mp4
http://$DEVSTACK_2:1235/the-xen-movie-ipod.mp4

EOF
set -x

ssh -q -A -o BatchMode=yes stack@$DEVSTACK_2 bash -s -- << EOF
set -eux
wget -qO infinite_migration.sh https://github.com/citrix-openstack/qa/raw/master/havana-demo/infinite_migration.sh
bash infinite_migration.sh
EOF
