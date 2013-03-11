#!/bin/bash

set -eu

TESTDIR=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)
SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Test delete instance with volume attached

positional arguments:
 SERVERNAME     The name of the XenServer, which is running devstack
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

set -exu

"$SCRIPTDIR/run-on-devstack.sh" "$SERVERNAME" "$TESTDIR/delete-instance-with-volume.sh"
