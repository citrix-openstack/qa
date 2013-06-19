#!/bin/bash
set -eu

XENSERVER_HOST="$1"
SCRIPT_TO_RUN="$2"
GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"}

function on_xenserver
{
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$XENSERVER_HOST" "$@"
}

#
# Find IP address of guest
#
GUEST_IP=$(on_xenserver xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
if [ -z "$GUEST_IP" ]
then
  echo "Failed to find IP address of DevStack DomU"
  exit 1
fi

shift 2

cat $SCRIPT_TO_RUN | on_xenserver ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "stack@$GUEST_IP" bash -s -- "$@"
