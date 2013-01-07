#!/bin/bash

# This script installs a DevStack DomU VM on a XenServer
#
# This script should be run on the XenServer host

set -eux

#
# Get Arguments
#
DevStackURL=$1
MirrorHttpHostname=$2
MirrorHttpDirectory=$3
MirrorHttpProxy=${4-""}

DhcpTimeout=120

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
sed -ie "s,\(d-i mirror/http/hostname string\).*,\1 ${MirrorHttpHostname},g" devstackubuntupreseed.cfg
sed -ie "s,\(d-i mirror/http/proxy string\).*,\1 ${MirrorHttpProxy},g" devstackubuntupreseed.cfg
sed -ie "s,\(d-i mirror/http/directory string\).*,\1 ${MirrorHttpDirectory},g" devstackubuntupreseed.cfg

# Additional DHCP timeout
sed -ie "s,#\(d-i netcfg/dhcp_timeout string\).*,\1 ${DhcpTimeout},g" devstackubuntupreseed.cfg

#
# Install VM
#
./install_os_domU.sh
