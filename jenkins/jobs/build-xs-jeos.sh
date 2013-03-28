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
SLAVE_IP=$(cat "$XSLIB/start-slave.sh" | $REMOTELIB/bash.sh root@$SERVERNAME)
echo "Starting job on $SLAVE_IP"

cat $XSLIB/add-extra-hdd.sh | $REMOTELIB/bash.sh root@$SERVERNAME slave 10GiB
cat $BUILDLIB/prepare-for-jeos.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP 
cat $BUILDLIB/enter-jeos-chroot.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP 
cat $BUILDLIB/setup-jeos.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP 
cat $BUILDLIB/quit-jeos-chroot.sh | $REMOTELIB/bash.sh ubuntu@$SLAVE_IP 
VDI=$(cat $XSLIB/detach-xvdb.sh | $REMOTELIB/bash.sh root@$SERVERNAME slave)

echo "VDI is: $VDI"
echo "Job finished on $SLAVE_IP"
