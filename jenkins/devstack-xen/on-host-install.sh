#!/bin/bash

# This script installs a DevStack DomU VM on a XenServer
#
# This script should be run on the XenServer host

set -eux

#
# Get Arguments
#
DevStackURL=$1
UbuntuMirror=$2

# Go into temp directory
SCRIPT_TMP_DIR=/tmp/jenkins_test
cd $SCRIPT_TMP_DIR

#
# Download DevStack
#
wget --output-document=devstack.zip --no-check-certificate $DevStackURL
unzip -o devstack.zip -d ./devstack
cd devstack/*/
cp ../../localrc .

#
# Prepare preseed
#
cd tools/xen
sed -ie "s,\(d-i mirror/http/hostname string\).*,\1 ${UbuntuMirror},g" devstackubuntupreseed.cfg

#
# Install VM
#
./install_os_domU.sh
