#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"
. "$thisdir/common-ssh.sh"

#
# Install second host (compute slave)
#

# Find IP address of master
export GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
export GUEST_IP=$(ssh_no_hosts "$Server1" "xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p'")

export Server=$Server2
. "$thisdir/run-devstack-xen.sh"
