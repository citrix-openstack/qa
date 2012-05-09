#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace

# get tempest from git hub
rm -rf /opt/stack/tempest
cd /opt/stack
git clone https://github.com/openstack/tempest.git
cd tempest

#
# Configure tempest
#
/opt/stack/devstack/tools/configure_tempest.sh

#
# Run tempest
#
nosetests -v tempest
