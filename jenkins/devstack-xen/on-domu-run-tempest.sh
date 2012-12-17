#!/usr/bin/env bash

# This script downloads, configures and
# then runs Tempest
#
# This runs on the DomU VM.

set -o errexit
set -o xtrace


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
nosetests --with-xunit -sv --nologcapture $@ tempest
