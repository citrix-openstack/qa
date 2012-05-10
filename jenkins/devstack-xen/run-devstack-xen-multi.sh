#!/bin/bash

# This script uses two XenServer hosts,
# installs a DevStack DomU on each hosts and
# configures one as an all-in-one deployment
# and a second as a compute slave.
# It then runs some tests on the all-in-one VM
#
# This script is designed to be run by Jenkins
#
# It assumes you have password-less login via ssh
# to your XenServer with the hostname $Server
#
# This script does the following:
# - finds the ip address of the domU on Server1
# - installs a domU compute slave on Server2
#
# The parmaters expected are:
# $Server1 - XenServer host for master compute DomU
# $Server2 - XenServer host for second compute DomU
# $DevStackURL - URL of the devstack zip file
# $localrcURL - URL to the localrc file
# $PreseedURL - URL to the ubuntu preseed URL
# $CleanTemplates - If true, clean the templates

set -eux
thisdir=$(dirname $(readlink -f "$0"))

#
# Find IP address of master domU VM
#
export GUEST_NAME=${GUEST_NAME:-"DevStackOSDomU"} # TODO - pull from config
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
