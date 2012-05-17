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
# $Server1 - XenServer host for master compute DomU
# $Server2 - XenServer host for second compute DomU
# $DevStackURL - URL of the devstack zip file
# $localrcURL - URL to the localrc file
# $PreseedURL - URL to the ubuntu preseed URL
# $CleanTemplates - If true, clean the templates

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
