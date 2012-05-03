#!/bin/bash

set -eux

# Find IP address of master
export GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
export GUEST_IP=$(xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
if [ -z "$GUEST_IP" ]
then
  echo "Failed to find IP address of DevStack DomU"
  exit 1
fi

# Run exercise.sh
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$GUEST_IP" \ "~/devstack/exercise.sh"

# TODO - run tempest
