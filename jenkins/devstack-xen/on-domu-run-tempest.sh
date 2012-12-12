#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace

TEMPEST_PARAMS=${1-""}

cd /opt/stack/tempest

#
# Output settings
#
cat ./etc/tempest.conf

#
# Run tempest
#
# TODO - need a better approach to select tests we skip
rm -f /opt/stack/tempest/tempest/tests/compute/test_console_output.py
nosetests $TEMPEST_PARAMS -v tempest -e "test_change_server_password"
