#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace

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
nosetests --attr=type=smoke -v tempest -e "test_change_server_password"
