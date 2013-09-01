#!/bin/bash
set -eu
function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 ISOURL XENSERVER [VIRTUAL_HYPERVISOR_COUNT]

Setup a mini-lab

Positional arguments:
  ISOURL    - An url containing the original XenServer iso
  XENSERVER - Target XenServer
  VIRTUAL_HYPERVISOR_COUNT - Number of virtual hypervisors to create,
                             default value is 1
USAGE
exit 1
}

ISOURL=${1:-$(print_usage_and_quit)}
XENSERVER=${2:-$(print_usage_and_quit)}
VIRTUAL_HYPERVISOR_COUNT=${3:-1}

set -x

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
NETNAME="stuffa"
DEVBOX_NAME="devbox"


"$REMOTELIB/bash.sh" "root@$XENSERVER" << EOF
set -eux
[ ! -z "\$(xe network-list name-label=$NETNAME --minimal)" ] || xe network-create name-label=$NETNAME
EOF

$THISDIR/create-devbox.sh $XENSERVER $NETNAME $DEVBOX_NAME

DEVBOX_IP=$(cat "$XSLIB/get-slave-ip.sh" | "$REMOTELIB/bash.sh" "$XENSERVER" "$DEVBOX_NAME")

for hypervisor_id in $(seq $VIRTUAL_HYPERVISOR_COUNT); do
    last_ip_digit=$(expr 9 + $hypervisor_id)
    vhip="192.168.32.$last_ip_digit"
    vhname="VH${hypervisor_id}"
    echo "Installing $vhname (hypervispr $hypervisor_id / $VIRTUAL_HYPERVISOR_COUNT) on $vhip"

    $THISDIR/create-virtual-hypervisor.sh \
        "$ISOURL" \
        "$XENSERVER" \
        "$vhname" \
        "$NETNAME" \
        "$DEVBOX_IP" \
        "$vhip"
done

echo "Setup finished. Gateway for your lab is: $DEVBOX_IP"
