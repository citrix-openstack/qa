#!/bin/bash

# This runs tests on a DevStack DomU VM
#
# This script should be run on the XenServer host
#
# It does the following:
# - find ip address of DevStack DomU
# - run exercise.sh on DevStack DomU
# - upload helper script and run Tempest on DevStack DomU
#
# It assumes the SSH keys on the XenServer were copied
# into the DevStack DomU

set -eux
thisdir=$(dirname $(readlink -f "$0"))

#
# Find IP address of master
#
GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config or params
GUEST_IP=$(xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
if [ -z "$GUEST_IP" ]
then
  echo "Failed to find IP address of DevStack DomU"
  exit 1
fi

#
# Run exercise.sh
#
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$GUEST_IP" \ "~/devstack/exercise.sh"

#
# Run devstack on the DomU
#
# TODO(johngarbutt) - fixme - needs to be updated for latest Tempest
# scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/on-domu-run-tempest.sh" "stack@$OPENSTACK_GUEST_IP:~/"
# ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$OPENSTACK_GUEST_IP" "~/on-domu-run-tempest.sh"
