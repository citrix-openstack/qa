#!/bin/bash

# This script installs a DevStack DomU VM on a XenServer
#
# This script should be run on the XenServer host
#
# It does the following:
# - downloads devstack code
# - download localrc
# - optionally modify localrc to configure VM as a slave compute node
# - download preseed file for ubuntu install
# - run install_os_domU.sh
# - it leaves you with a running DevStack DomU

set -eux

#
# Get Arguments
#
RunExercises=$1
RunTempest=$2
DevStackURL=$3
LocalrcURL=$4
PreseedURL=$5
GuestIp=$6
CleanTemplates=$7

# Go into temp directory
SCRIPT_TMP_DIR=/tmp/jenkins_test
cd $SCRIPT_TMP_DIR

#
# Download DevStack
#
wget --output-document=devstack.zip --no-check-certificate $DevStackURL
unzip -o devstack.zip -d ./devstack
cd devstack/*/

#
# Download localrc
#
wget --output-document=localrc --no-check-certificate $LocalrcURL

#
# Optionally modify localrc
# to create a secondary compute host
#
if [ "$GuestIp" != "false" ]
then
    cat <<EOF >>localrc
# appended by jenkins
# TODO - g-api only added due to dependency error with glance client
ENABLED_SERVICES=n-cpu,n-net,n-api,g-api
MYSQL_HOST=$GuestIp
RABBIT_HOST=$GuestIp
KEYSTONE_AUTH_HOST=$GuestIp
GLANCE_HOSTPORT=$GuestIp:9292

# TODO - allow these to be configured
PUB_IP=172.24.4.11
VM_IP=10.255.255.254
GUEST_NAME=DevStackComputeSlave
EOF
fi

#
# Add the clean templates setting
# and correct the IP address for dom0
#
XenApiIP=`ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`
cat <<EOF >>localrc
CLEAN_TEMPLATES=$CleanTemplates
XENAPI_CONNECTION_URL="http://$XenApiIP"
VNCSERVER_PROXYCLIENT_ADDRESS=$XenApiIP
EOF

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
