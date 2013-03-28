#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

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

while true
do
    VM=$($REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/start-vm-with-vdi.sh "$VDI")

    echo "VM launched. Please press Enter as finished (temp VM is $VM)"
    read

    $REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/stop-destroy-vm-keep-vdi.sh "$VM"
    $REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/add-xvdb-to-slave.sh "$VDI"

    echo "xvdb attached to slave VM (Enter to continue)"
    read

    SLAVE_IP=$($REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/get-slave-ip.sh)
    $REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/enter-jeos-chroot.sh"

    echo "Please press Enter as finished with chroot on $SLAVE_IP"
    read

    $REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/quit-jeos-chroot.sh"
    $REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/detach-xvdb.sh slave

    echo "Now you can type quit to exit, or anything else to carry on"
    read COMMAND
    if [ "$COMMAND" = "quit" ];
    then
        exit 0
    fi
done
