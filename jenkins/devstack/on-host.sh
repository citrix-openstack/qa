#!/bin/bash

set -eux

# tidy up the scripts we copied over on exit
SCRIPT_TMP_DIR=/tmp/jenkins_test
add_on_exit "rm -rf $SCRIPT_TMP_DIR"
cd $SCRIPT_TMP_DIR

# import the common utils
. "$SCRIPT_TMP_DIR/common.sh"
. "$SCRIPT_TMP_DIR/common-ssh.sh"

#
# Make sure we have git and other bits we need
#
if ! which git; then
    # Install basics for vi and git
    yum -y  --enablerepo=base install gcc make vim-enhanced zlib-devel openssl-devel
    yum --enablerepo=base install -y parted

    GITDIR=/tmp/git-1.7.7
    cd /tmp
    rm -rf $GITDIR*
    wget http://git-core.googlecode.com/files/git-1.7.7.tar.gz
    tar xfv git-1.7.7.tar.gz
    cd $GITDIR
    ./configure
    make install
    cd $TOP_DIR
fi

#
# Checkout nova, to get xapi plugins
#
cd $SCRIPT_TMP_DIR/devstack/tools/xen
TOP_DIR=$(pwd)

NOVA_REPO=git://github.com/openstack/nova.git
NOVA_BRANCH=master
git clone $NOVA_REPO
cd nova
git checkout $NOVA_BRANCH

#
# Install plugins
#
cp -pr $TOP_DIR/nova/plugins/xenserver/xenapi/etc/xapi.d /etc/
chmod a+x /etc/xapi.d/plugins/*

#
# Install DomU devstack VM
#
mkdir -p /boot/guest
cd $TOP_DIR
guest=${GUEST_NAME:-ALLINONE}
./build_domU.sh

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

#
# Run some tests to make sure everything is working
#
scp_no_hosts "$SCRIPT_TMP_DIR/run-excercise.sh" "stack@$guestnode:~/"
ssh_no_hosts  "stack@$guestnode" \ "~/run-excercise.sh"

echo "on-host exiting"
