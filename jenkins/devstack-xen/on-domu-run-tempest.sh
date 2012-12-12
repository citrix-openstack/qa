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
nosetests --with-xunit -sv --nologcapture $TEMPEST_PARAMS tempest
