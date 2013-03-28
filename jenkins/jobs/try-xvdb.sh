#!/bin/bash

set -eu

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME VDI

Try out a VDI

positional arguments:
 SERVERNAME     The name of the XenServer to use
 VDI            The uuid of the VDI
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
VDI="${2-$(print_usage_and_die)}"

function run_on
{
    THE_IP="$1"
    SCRIPT="$2"
    shift 2

    cat "$SCRIPT" | ssh -q -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$THE_IP" bash -s -- "$@"
}


while true
do
    VM=$($SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/start-vm-with-vdi.sh "$VDI")

    echo "VM launched. Please press Enter as finished (temp VM is $VM)"
    read

    $SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/stop-destroy-vm-keep-vdi.sh "$VM"
    $SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/add-xvdb-to-slave.sh "$VDI"

    echo "xvdb attached to slave VM (Enter to continue)"
    read

    SLAVE_IP=$($SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/get-slave-ip.sh)
    run_on $SLAVE_IP "$BUILDLIB/enter-jeos-chroot.sh"

    echo "Please press Enter as finished with chroot on $SLAVE_IP"
    read

    run_on $SLAVE_IP "$BUILDLIB/quit-jeos-chroot.sh"
    $SCRIPTDIR/run-on-xenserver.sh $SERVERNAME $XSLIB/detach-xvdb.sh slave

    echo "Now you can type quit to exit, or anything else to carry on"
    read COMMAND
    if [ "$COMMAND" = "quit" ];
    then
        exit 0
    fi
done
