#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Create a devbox on a XenServer - a router ubuntu VM

positional arguments:
 XENSERVERNAME     The name of the XenServer
 NETNAME           The name of the network to use
 DEVBOX_NAME       The name of the devbox
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"
NETNAME="${2-$(print_usage_and_die)}"
DEVBOX_NAME="${3-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME" "1=$NETNAME" "$DEVBOX_NAME")

cat $THISDIR/in_vm_scripts/gateway.sh | "$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP"
