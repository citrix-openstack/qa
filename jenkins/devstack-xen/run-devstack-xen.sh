#!/bin/bash

# This script installs a DevStack DomU VM on
# the specified XenServer.
#
# This script is designed to be run by Jenkins
#
# It assumes you have password-less login via ssh
# to your XenServer with the hostname $Server
#
# This script does the following:
# - deals with parameter defaults
# - creates a fresh temp directory on the XenServer
# - uploads and runs the on-host-install.sh script

set -eux
thisdir=$(dirname $(readlink -f "$0"))

function on_xenserver
{
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$Server" "$@"
}

# The parmaters expected are:
# $Server - XenServer host for compute DomU
# $XenServerVmVlan - Vlan ID
# $XenServerPassword - Password for your XenServer

# $DevStackURL (optional) - URL of the devstack zip file
# $CleanTemplates (default:false) - If true, clean the templates
#
# Internal param:
# $GuestIP - pram used to trigger localrc editing
#            to allow secondary compute node

#
# Get parameters
#
Server="$Server"
XenServerVmVlan="$XenServerVmVlan"
XenServerPassword="$XenServerPassword"

DevStackURL=${DevStackURL-"https://github.com/openstack-dev/devstack/zipball/master"}
CleanTemplates="${CleanTemplates-false}"

LocalrcAppend=${LocalrcAppend-"localrc.append"}

# GUEST_IP is used by run-devstack-xen-mutli
# to trigger a re-write of the localrc file
GuestIP="${GUEST_IP-false}"

#
# Clean directory, create directory and
# copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test
ssh "$Server" "rm -rf $SCRIPT_TMP_DIR"
ssh "$Server" "mkdir -p $SCRIPT_TMP_DIR"


TEMPLATE_LOCALRC="${thisdir}/localrc.template"
GENERATED_LOCALRC=`tempfile`


# Generate localrc
cat $TEMPLATE_LOCALRC |
sed -e "s,%XenServerVmVlan%,$XenServerVmVlan,g;
        s,%XenServerPassword%,$XenServerPassword,g;
" > $GENERATED_LOCALRC


#
# Optionally modify localrc
# to create a secondary compute host
#
if [ "$GuestIP" != "false" ]
then
    cat <<EOF >> $GENERATED_LOCALRC
# appended by jenkins
# TODO - g-api only added due to dependency error with glance client
ENABLED_SERVICES="n-cpu,n-net,n-api,g-api,-mysql"
DATABASE_TYPE=mysql
MYSQL_HOST=$GuestIP
RABBIT_HOST=$GuestIP
KEYSTONE_AUTH_HOST=$GuestIP
GLANCE_HOSTPORT=$GuestIP:9292

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
XenApiIP=`on_xenserver ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"`
cat <<EOF >> $GENERATED_LOCALRC
CLEAN_TEMPLATES=$CleanTemplates
XENAPI_CONNECTION_URL="http://$XenApiIP"
VNCSERVER_PROXYCLIENT_ADDRESS=$XenApiIP
EOF

[ -e "${LocalrcAppend}" ] && ( cat "$LocalrcAppend" >> $GENERATED_LOCALRC ) || echo "$LocalrcAppend was not found, not appending to localrc"

#
# Show the content on the localrc file
#
echo "Content of localrc file:"
cat $GENERATED_LOCALRC
echo "** end of localrc file **"

#
# Run the next steps on the XenServer host
#
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$thisdir/on-host-install.sh" "root@$Server:$SCRIPT_TMP_DIR"
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$GENERATED_LOCALRC" "root@$Server:$SCRIPT_TMP_DIR/localrc"
rm $GENERATED_LOCALRC
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$Server" "$SCRIPT_TMP_DIR/on-host-install.sh" "${DevStackURL}"
