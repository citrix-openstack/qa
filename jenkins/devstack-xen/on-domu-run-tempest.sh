#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace

SMOKE_ONLY=$1


cd /opt/stack/tempest

#
# Output settings
#
cat ./etc/tempest.conf

#
# Update nosetests if using oneiric
#
if grep -q "oneiric" /etc/*-release;
then
  sudo pip install -U nose
fi

#
# Run tempest
#
if [ "$SMOKE_ONLY" = "true" ];
then
# test_ec2_instance_run.py - because console support is not available
    TEMPEST_ARGS="-I test_ec2_volumes.py -I test_ec2_instance_run.py --attr=type=smoke"
else
    TEMPEST_ARGS=""
fi

nosetests --with-xunit -sv --nologcapture $TEMPEST_ARGS tempest
