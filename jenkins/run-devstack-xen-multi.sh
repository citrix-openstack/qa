#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"
. "$thisdir/common-ssh.sh"

#
# Install first host (master)
#
server=$Server1
GUEST_IP=""

. ./run-devstack-xen.sh

#
# Install second host (compute slave)
#
server=$Server2

# Find IP address of master
GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
GUEST_IP=$(ssh_no_hosts "$server" "xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p'")

. ./run-devstack-xen.sh
