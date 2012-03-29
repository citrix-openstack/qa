#!/bin/bash

set -eux

# tidy up the scripts we copied over on exit
SCRIPT_TMP_DIR=/tmp/jenkins_test
cd $SCRIPT_TMP_DIR

# import the common utils
. "$SCRIPT_TMP_DIR/common.sh"
. "$SCRIPT_TMP_DIR/common-ssh.sh"

# clean up after we are done
add_on_exit "rm -rf $SCRIPT_TMP_DIR"

#
# Make sure have the software we need on Dom0
#
if ! which parted; then
    yum --enablerepo=base install -y parted
fi

#
# Install latest XAPI plugins
#
cd $SCRIPT_TMP_DIR/devstack/tools/xen
TOP_DIR=$(pwd)

wget https://github.com/openstack/nova/zipball/master --no-check-certificate
unzip -o master -d ./nova
cp -pr ./nova/*/plugins/xenserver/xenapi/etc/xapi.d /etc/
chmod a+x /etc/xapi.d/plugins/*

#
# Install DomU devstack VM
#
mkdir -p /boot/guest
cd $TOP_DIR
guest=${GUEST_NAME:-HEADNODE}
HEAD_PUB_IP="dhcp" HEAD_MGT_IP=192.168.1.1 COMPUTE_PUB_IP="dhcp" COMPUTE_MGT_IP=192.168.1.2 FLOATING_RANGE=10.0.0.2/30 ./install_domU_multi.sh

#
# Upload the key to DomU devstack VM (like in prepare_guest.sh)
#
sleep 60
guestnode=$(xe vm-list --minimal name-label=$guest params=networks |  sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi
upload_key $guestnode $password $keyfile stack

#
# Check that dev stack has completed
#
scp_no_hosts "$SCRIPT_TMP_DIR/verify.sh" "stack@$guestnode:~/"
ssh_no_hosts  "stack@$guestnode" \ "~/verify.sh"

echo "on-host-multi exiting"
