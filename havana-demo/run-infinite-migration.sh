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

ssh -q -A -o BatchMode=yes stack@$DEVSTACK_2 bash -s -- << EOF
set -eux
wget -qO infinite_migration.sh https://github.com/citrix-openstack/qa/raw/master/havana-demo/infinite_migration.sh
bash infinite_migration.sh
EOF
