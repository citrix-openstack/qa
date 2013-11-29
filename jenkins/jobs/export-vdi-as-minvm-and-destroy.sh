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

VM=$(cat $XSLIB/create-vm-with-vdi.sh | $REMOTELIB/bash.sh root@$SERVERNAME "$VDI")

$REMOTELIB/bash.sh root@$SERVERNAME << EOF
set -eux
rm -f /root/minvm.xva
xe vm-export uuid=$VM compress=True filename=/root/minvm.xva
xe vm-uninstall uuid=$VM force=True
xe vdi-destroy uuid=$VDI
EOF
