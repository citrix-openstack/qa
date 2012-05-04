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
# - deals with parameter defaults
# - creates a fresh temp directory on the XenServer
# - uploads and runs the on-host-install.sh script
#
# The parmaters expected are:
# $Server1 - XenServer host for master compute DomU
# $Server2 - XenServer host for second compute DomU
# $DevStackURL - URL of the devstack zip file
# $localrcURL - URL to the localrc file
# $PreseedURL - URL to the ubuntu preseed URL

set -eux
thisdir=$(dirname $(readlink -f "$0"))

#
# Install first host
#
export Server=$Server1
. "$thisdir/run-devstack-xen.sh"

#
# Install second host (the compute slave)
#
. "$thisdir/run-devstack-xen-multi.sh"

#
# Run tests
#
export Server=$Server1
. "$thisdir/run-devstack-xen-tests.sh"
