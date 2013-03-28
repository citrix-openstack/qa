#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Build an Ubuntu JeOS disk image.

positional arguments:
 SERVERNAME     The name of the XenServer to use for the build
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

echo "Spinning up virtual machine"
SLAVE_IP=$($REMOTELIB/bash.sh root@$SERVERNAME "$XSLIB/start-slave.sh")
echo "Starting job on $SLAVE_IP"

$REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/add-extra-hdd.sh slave 10GiB
$REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/prepare-for-jeos.sh"
$REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/enter-jeos-chroot.sh"
$REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/setup-jeos.sh"
$REMOTELIB/bash.sh ubuntu@$SLAVE_IP "$BUILDLIB/quit-jeos-chroot.sh"
VDI=$($REMOTELIB/bash.sh root@$SERVERNAME $XSLIB/detach-xvdb.sh slave)

echo "VDI is: $VDI"
echo "Job finished on $SLAVE_IP"
