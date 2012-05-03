#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

server=$Server

# copy over test script
tmpdir=/tmp/jenkins_run_tests
ssh "$server" "rm -rf $tmpdir"
ssh "$server" "mkdir -p $tmpdir"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/devstack-xen/on-host-tests.sh" "$server:$tmpdir"

# run test script
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$server" "$tmpdir/on-host-tests.sh"
