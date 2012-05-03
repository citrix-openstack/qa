#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

#
# Install second host (compute slave)
#

# Find IP address of master
export GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
export GUEST_IP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$Server" "xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p'")

if [ -z "$GUEST_IP" ]
then
  echo "Failed to find IP address of DevStack DomU on $Server1"
  exit 1
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$GUEST_IP" \ "~/devstack/exercise.sh"