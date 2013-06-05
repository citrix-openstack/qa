#!/bin/bash
set -eu
function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 ISOURL XENSERVER

Setup a mini-lab

Positional arguments:
  ISOURL    - An url containing the original XenServer iso
  XENSERVER - Target XenServer
USAGE
exit 1
}

ISOURL=${1-$(print_usage_and_quit)}
XENSERVER=${2-$(print_usage_and_quit)}

set -x

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)


"$REMOTELIB/bash.sh" "root@$XENSERVER" << EOF
set -eux
[ ! -z "\$(xe network-list name-label=stuffa --minimal)" ] || xe network-create name-label=stuffa
EOF

$THISDIR/create-devbox.sh $XENSERVER stuffa

DEVBOX_IP=$(cat "$XSLIB/get-slave-ip.sh" | "$REMOTELIB/bash.sh" "$XENSERVER")

$THISDIR/create-virtual-hypervisor.sh \
    "$ISOURL" \
    "$XENSERVER" \
    "VH1" \
    "stuffa" \
    "$DEVBOX_IP"
