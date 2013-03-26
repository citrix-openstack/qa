#!/bin/bash

set -eu

OSLIBDIR=$(cd $(dirname $(readlink -f "$0")) && cd oslib && pwd)
XSDIR=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Add an extra disk to DevStackOSDomU

positional arguments:
 SERVERNAME     The name of the XenServer, which is running devstack
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"


$SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSDIR/add-extra-hdd.sh
$SCRIPTDIR/run-on-devstack.sh $SERVERNAME $OSLIBDIR/setup-extra-hdd.sh
