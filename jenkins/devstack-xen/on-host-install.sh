#!/bin/bash

# This script installs a DevStack DomU VM on a XenServer
#
# This script should be run on the XenServer host

set -eux

#
# Get Arguments
#
DevStackURL=$1
PreseedURL=$2

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
# Download preseed
#
cd tools/xen
rm devstackubuntupreseed.cfg
wget --output-document=devstackubuntupreseed.cfg --no-check-certificate $PreseedURL


#
# Install VM
#
./install_os_domU.sh
