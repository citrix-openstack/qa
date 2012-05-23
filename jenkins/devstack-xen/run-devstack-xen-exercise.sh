#!/bin/bash

# This runs tests on a DevStack DomU OpenStack deployment
#
# This script is designed to be run by Jenkins
#
# It assumes the SSH keys on the XenServer were copied
# into the DevStack DomU and you have password-less
# login via ssh to your XenServer
#
# This script does the following:
# - creates a fresh temp directory on the XenServer
# - uploads and runs the on-host-run-exercise.sh script
#
# The parmaters expected are:
# $Server - XenServer host that has a DevStack DomU VM

set -eux
thisdir=$(dirname $(readlink -f "$0"))
server=$Server

#
# Copy over test scripts
# into fresh tmp directory
#
tmpdir=/tmp/jenkins_run_tests
ssh "$server" "rm -rf $tmpdir"
ssh "$server" "mkdir -p $tmpdir"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/on-host-run-exercise.sh" "root@$server:$tmpdir"

#
# Run tests
#
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$server" "$tmpdir/on-host-run-exercise.sh"
