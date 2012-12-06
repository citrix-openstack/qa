#!/bin/bash

# This script installs a DevStack DomU VM on
# the specified XenServer.
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

set -eux
thisdir=$(dirname $(readlink -f "$0"))

# The parmaters expected are:
# $Server1 - XenServer host for master compute DomU
# $Server2 - XenServer host for second compute DomU
# $DevStackURL - URL of the devstack zip file
# $localrcURL - URL to the localrc file
# $PreseedURL - URL to the ubuntu preseed URL
# $CleanTemplates - If true, clean the templates
#
# Internal param:
# $GuestIp - pram used to trigger localrc editing
#            to allow secondary compute node

#
# Get parameters
#
Server="$Server"
LocalrcURL="$localrcURL"
PreseedURL="$PreseedURL"
XenServerVmVlan="$XenServerVmVlan"
XenServerPassword="$XenServerPassword"

DefaultDevStackURL="https://github.com/openstack-dev/devstack/zipball/master"
DevStackURL="${DevStackURL-$DefaultDevStackURL}"

RunExercises="${RunExercises-false}"
RunTempest="${RunTempest-false}"
CleanTemplates="${CleanTemplates-false}"

# GUEST_IP is used by run-devstack-xen-mutli
# to trigger a re-write of the localrc file
GuestIP="${GUEST_IP-false}"

#
# Clean directory, create directory and
# copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test
ssh "$Server" "rm -rf $SCRIPT_TMP_DIR"
ssh "$Server" "mkdir -p $SCRIPT_TMP_DIR"

#
# Run the next steps on the XenServer host
#
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/on-host-install.sh" "root@$Server:$SCRIPT_TMP_DIR"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/*.template" "root@$Server:$SCRIPT_TMP_DIR"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$Server" "$SCRIPT_TMP_DIR/on-host-install.sh" "${RunExercises}" "${RunTempest}" "${DevStackURL}" "${LocalrcURL}" "${PreseedURL}" "${GuestIP}" "${CleanTemplates}" "${XenServerVmVlan}" "${XenServerPassword}"
