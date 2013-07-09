#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Create a ceph box

positional arguments:
 XENSERVERNAME     The name of the XenServer
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_CEPH_SETUP
set -eux

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qy update
sudo apt-get -qy dist-upgrade

wget -q -O- 'https://ceph.com/git/?p=ceph.git;a=blob_plain;f=keys/release.asc' | sudo apt-key add -
echo deb http://ceph.com/debian-cuttlefish/ \$(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/ceph.list
sudo apt-get -qy update 
sudo apt-get install -qy ceph

CEPH_HOST="\$(hostname -s)"
CEPH_IP="\$(ifconfig eth0 | sed -ne 's/^.*inet addr:\([^ ]*\) .*$/\1/p')"

sudo sed -i "1i\$CEPH_IP \$CEPH_HOST" /etc/hosts

sudo tee /etc/ceph/ceph.conf <<EOT
[global]
        auth cluster required = none
        auth service required = none
        auth client required = none

[osd]
        osd journal size = 1000
        filestore xattr use omap = true

[mon.a]
        host = \$CEPH_HOST
        mon addr = \$CEPH_IP:6789

[osd.0]
        host = \$CEPH_HOST

[osd.1]
        host = \$CEPH_HOST

[mds.a]
        host = \$CEPH_HOST
EOT

sudo mkdir -p /var/lib/ceph/osd/ceph-0
sudo mkdir -p /var/lib/ceph/osd/ceph-1
sudo mkdir -p /var/lib/ceph/mon/ceph-a
sudo mkdir -p /var/lib/ceph/mds/ceph-a

cd /etc/ceph
sudo mkcephfs -a -c /etc/ceph/ceph.conf -k ceph.keyring

sudo service ceph -a start

while ! timeout 1 sudo ceph health; do
    sleep 1
done

while [ "HEALTH_OK" != "\$(sudo ceph health)" ]; do
    sleep 1
done

sudo ceph osd pool create volumes 8
sudo ceph osd pool create images 8

sudo ceph auth get-or-create client.volumes mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rx pool=images' -o /etc/ceph/client.volumes.keyring
sudo ceph auth get-or-create client.images mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' -o /etc/ceph/client.images.keyring
END_OF_CEPH_SETUP

echo "Ceph installed on $SLAVE_IP"
