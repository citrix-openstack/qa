#!/bin/bash

# This script uses two XenServer hosts,
# installs a DevStack DomU on each hosts and
# configures one as an all-in-one deployment
# and a second as a compute slave.
#
# This script is designed to be run by Jenkins
#
# It assumes you have password-less login via ssh
# to your XenServer with the hostname $Server
#
# The parmaters expected are:
# The same parameters as for run-devstack-xen.sh
# Instead of Server:
# $Server1 - XenServer host for master compute DomU
# $Server2 - XenServer host for second compute DomU

set -eux
thisdir=$(dirname $(readlink -f "$0"))

#
# Install first host - this is a regular installation
#
export Server=$Server1
. "$thisdir/run-devstack-xen.sh"

#
# Export GUEST_IP
#
GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
export GUEST_IP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$Server1" "xe vm-list --minimal name-label=$GUEST_NAME params=networks | sed -ne 's,^.*2/ip: \([0-9.]*\).*$,\1,p'")
if [ -z "$GUEST_IP" ]
then
  echo "Failed to find IP address of DevStack DomU on $Server1"
  exit 1
fi

#
# Install the second domU VM
#
export Server=$Server2
. "$thisdir/run-devstack-xen.sh"
