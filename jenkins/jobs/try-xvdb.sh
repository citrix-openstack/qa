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
    VM=$(cat $XSLIB/start-vm-with-vdi.sh | $REMOTELIB/bash.sh root@$SERVERNAME "$VDI")

    echo "VM launched. Please press Enter as finished (temp VM is $VM)"
    read

    cat $XSLIB/stop-destroy-vm-keep-vdi.sh | $REMOTELIB/bash.sh root@$SERVERNAME "$VM"
    cat $XSLIB/add-xvdb-to-slave.sh | $REMOTELIB/bash.sh root@$SERVERNAME "$VDI"

    echo "xvdb attached to slave VM (Enter to continue)"
    read

    SLAVE_IP=$(cat $XSLIB/get-slave-ip.sh | $REMOTELIB/bash.sh root@$SERVERNAME)
    cat $BUILDLIB/enter-jeos-chroot.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP

    echo "Please press Enter as finished with chroot on $SLAVE_IP"
    read

    cat $BUILDLIB/quit-jeos-chroot.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP
    cat $XSLIB/detach-xvdb.sh | $REMOTELIB/bash.sh root@$SERVERNAME slave

    echo "Now you can type quit to exit, or anything else to carry on"
    read COMMAND
    if [ "$COMMAND" = "quit" ];
    then
        exit 0
    fi
done
