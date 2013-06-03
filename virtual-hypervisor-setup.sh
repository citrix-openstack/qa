#!/bin/bash
set -eu

function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 ISOURL XENSERVER

Re-master an Ubuntu iso file for unattended operation.

Positional arguments:
  ISOURL    - An url containing the original XenServer iso
  XENSERVER - Target XenServer
  VMNAME    - Name of the VM
USAGE
exit 1
}

ISOURL=${1-$(print_usage_and_quit)}
XENSERVER=${2-$(print_usage_and_quit)}
VMNAME=${3-$(print_usage_and_quit)}

TEMPDIR=$(mktemp -d)

XSISOFILE="$TEMPDIR/xs.iso"
CUSTOMXSISO="$TEMPDIR/xscustom.iso"
ANSWERFILE="$TEMPDIR/answerfile"
VHROOT="$TEMPDIR/vh"

ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER" bash -s -- << EOF
xe vm-uninstall vm="$VMNAME" force=true | true
EOF

git clone git://github.com/matelakat/virtual-hypervisor.git "$VHROOT"

wget -qO "$TEMPDIR/xs.iso" "$ISOURL"

$VHROOT/scripts/generate_answerfile.sh \
    dhcp > "$ANSWERFILE"

$VHROOT/scripts/create_customxs_iso.sh \
    "$XSISOFILE" "$CUSTOMXSISO" "$ANSWERFILE"

$VHROOT/scripts/xs_start_create_vm_with_cdrom.sh \
    "$CUSTOMXSISO" "$XENSERVER" home "$VMNAME"

ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER" bash -s -- << EOF
xe vm-start vm="$VMNAME"
EOF

rm -rf "$TEMPDIR"
