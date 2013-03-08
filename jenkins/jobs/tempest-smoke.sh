#!/bin/bash

set -eu

TESTDIR=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)
XSDIR=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Run XenServer tempest tests

positional arguments:
 SERVERNAME     The name of the XenServer, which is running devstack
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"


$SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSDIR/configure_for_resize.sh
$SCRIPTDIR/run-on-devstack.sh $SERVERNAME $TESTDIR/setup_for_tempest.sh
$SCRIPTDIR/run-on-devstack.sh $SERVERNAME $TESTDIR/run_tempest_smoke.sh
