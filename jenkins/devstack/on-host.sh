#!/bin/bash

set -eux

basedir="/root"
. "$basedir/common.sh"
. "$basedir/common-ssh.sh"

add_on_exit "rm -rf /root/devstack"

# compute service
NOVA_REPO=git://github.com/openstack/nova.git
NOVA_BRANCH=master

cd /root/devstack/tools/xen
TOP_DIR=$(pwd)

# Install basics for vi and git
yum -y  --enablerepo=base install gcc make vim-enhanced zlib-devel openssl-devel

# Make sure we have git
if ! which git; then
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

# Checkout nova
if [ ! -d $TOP_DIR/nova ]; then
    git clone $NOVA_REPO
    cd $TOP_DIR/nova
    git checkout $NOVA_BRANCH
fi

# Install plugins
cp -pr $TOP_DIR/nova/plugins/xenserver/xenapi/etc/xapi.d /etc/
chmod a+x /etc/xapi.d/plugins/*
yum --enablerepo=base install -y parted
mkdir -p /boot/guest

cd $TOP_DIR
guest=${GUEST_NAME:-ALLINONE}
./build_domU.sh
guestnode=$(xe vm-list --minimal name-label=$guest params=networks |  sed -ne 's,^.*3/ip: \([0-9.]*\).*$,\1,p')
keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi
upload_key $guestnode $password $keyfile stack
scp_no_hosts "$basedir/verify.sh" "stack@$guestnode:~/"
ssh_no_hosts  "stack@$guestnode" \ "~/verify.sh"