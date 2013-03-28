#!/bin/bash

set -eu

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Build an Ubuntu JeOS

positional arguments:
 SERVERNAME     The name of the XenServer to use for the build
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

function start_slave
{
    "$SCRIPTDIR/run-on-xenserver.sh" "$SERVERNAME" "$XSLIB/start-slave.sh"
}

function run_on
{
    THE_IP="$1"
    SCRIPT="$2"
    shift 2

    cat "$SCRIPT" | ssh -q -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$THE_IP" bash -s -- "$@"
}

echo "Spinning up virtual machine"
SLAVE_IP=$(start_slave)
echo "Starting job on $SLAVE_IP"

$SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/add-extra-hdd.sh slave 10GiB
run_on $SLAVE_IP "$BUILDLIB/prepare-for-jeos.sh"
run_on $SLAVE_IP "$BUILDLIB/enter-jeos-chroot.sh"
run_on $SLAVE_IP "$BUILDLIB/setup-jeos.sh"
run_on $SLAVE_IP "$BUILDLIB/quit-jeos-chroot.sh"
XVDB=$($SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/detach-xvdb.sh slave)
echo "XVDB is: $XVDB"
echo "Job finished on $SLAVE_IP"
