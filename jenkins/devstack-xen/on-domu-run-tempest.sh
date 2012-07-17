#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace

TEMPEST_PARAMS=${1-""}

# get nova branch
BRANCH=$(cat /opt/stack/nova/.git/HEAD | sed -ne 's,^.*heads/\([a-x0-9/]*\)$,\1,p')

# get tempest from git hub
rm -rf /opt/stack/tempest
cd /opt/stack
git clone https://github.com/openstack/tempest.git
cd tempest
git checkout $BRANCH

#
# Configure tempest
#
/opt/stack/devstack/tools/configure_tempest.sh

#
# Run tempest
#
# TODO - need a better approach to select tests we skip
rm -f /opt/stack/tempest/tempest/tests/compute/test_console_output.py
nosetests $TEMPEST_PARAMS -v tempest -e "test_change_server_password"
