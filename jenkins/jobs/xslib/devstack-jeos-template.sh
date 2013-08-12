#!/bin/bash
set -eux

ACTION="$1"
TEMPLATE_NFS_DIR="$2"
TEMPLATE_FILENAME="$3"
TEMPLATE_NAME="$4"

VM="$(xe template-list name-label="$TEMPLATE_NAME" --minimal)"

function import() {
    if [ -z "$VM" ]
    then
        mountdir=$(mktemp -d)

        mount -t nfs "$TEMPLATE_NFS_DIR" "$mountdir"
        VM=$(xe vm-import filename="$mountdir/$TEMPLATE_FILENAME")
        umount "$mountdir"
    else
        echo "Template already imported"
        exit 0
    fi
}

function export() {
    if [ -z "$VM" ]
    then
        echo "No template found"
        exit 1
    else
        mountdir=$(mktemp -d)

        mount -t nfs "$TEMPLATE_NFS_DIR" "$mountdir"
        xe template-export template-uuid=$VM filename="$mountdir/$TEMPLATE_FILENAME"
        umount "$mountdir"
    fi
}

$ACTION

exit 0

# An example export:
cat xslib/devstack-jeos-template.sh |
  remote/bash.sh taunton.eng.hq.xensource.com \
    export \
      copper.eng.hq.xensource.com:/exported-vms \
      devstack-jeos.xva \
        jeos_template_for_devstack

# An example import:
cat xslib/devstack-jeos-template.sh |
  remote/bash.sh cottington.eng.hq.xensource.com \
    import \
      copper.eng.hq.xensource.com:/exported-vms \
      devstack-jeos.xva \
        jeos_template_for_devstack
