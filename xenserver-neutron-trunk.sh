#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER_IP XENSERVER_PASS

A simple script to test a XenServer devstack with Neutron

positional arguments:
 XENSERVER_IP     The IP address of the XenServer
 XENSERVER_PASS   The root password for the XenServer

An example run:

$0 10.219.10.25 mypassword
EOF
exit 1
}

XENSERVER_IP="${1-$(print_usage_and_die)}"
XENSERVER_PASS="${2-$(print_usage_and_die)}"

set -eux

ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER_IP" bash -s -- << END_OF_XENSERVER_COMMANDS
set -exu
rm -rf "devstack-master"
wget -qO - https://github.com/openstack-dev/devstack/archive/master.tar.gz |
    tar -xzf -
cd "devstack-master"

cat << LOCALRC_CONTENT_ENDS_HERE > localrc
# Passwords
MYSQL_PASSWORD=citrix
SERVICE_TOKEN=citrix
ADMIN_PASSWORD=citrix
SERVICE_PASSWORD=citrix
RABBIT_PASSWORD=citrix
GUEST_PASSWORD=citrix
XENAPI_PASSWORD="$XENSERVER_PASS"
SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"

# Use xvdb for backing cinder volumes
XEN_XVDB_SIZE_GB=10
VOLUME_BACKING_DEVICE=/dev/xvdb

# Tempest
DEFAULT_INSTANCE_TYPE="m1.tiny"

# Compute settings
EXTRA_OPTS=("xenapi_disable_agent=True")
API_RATE_LIMIT=False
VIRT_DRIVER=xenserver

# Use a XenServer Image
IMAGE_URLS="https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz"
DEFAULT_IMAGE_NAME="cirros-0.3.0-x86_64-disk"

# OpenStack VM settings
OSDOMU_MEM_MB=4096
UBUNTU_INST_RELEASE=precise
UBUNTU_INST_IFACE="eth2"
OSDOMU_VDI_GB=40

# Exercise settings
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

# Increase boot timeout for quantum tests:
BOOT_TIMEOUT=500

# DevStack settings
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/
VERBOSE=False

# XenAPI specific
XENAPI_CONNECTION_URL="http://$XENSERVER_IP"
VNCSERVER_PROXYCLIENT_ADDRESS="$XENSERVER_IP"

MULTI_HOST=False

# Skip boot from volume exercise
SKIP_EXERCISES=boot_from_volume,client-env

# Quantum specific
Q_PLUGIN=openvswitch
ENABLED_SERVICES+=,tempest,quantum,q-svc,q-agt,q-dhcp,q-l3,q-meta,q-domua,-n-net

# Disable security groups
Q_USE_SECGROUP=False

# With XenServer single box install, VLANs need to be enabled
ENABLE_TENANT_VLANS="True"
OVS_VLAN_RANGES="physnet1:1000:1024"

# CLEAN_TEMPLATES=true

Q_USE_DEBUG_COMMAND=True

LOCALRC_CONTENT_ENDS_HERE

cd tools/xen
./install_os_domU.sh
END_OF_XENSERVER_COMMANDS


# Run tests
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER_IP" bash -s -- << END_OF_XENSERVER_COMMANDS
set -exu
GUEST_IP=\$(. devstack-master/tools/xen/functions && find_ip_by_name DevStackOSDomU 0)
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "stack@\$GUEST_IP" bash -s -- << END_OF_DEVSTACK_COMMANDS
set -exu
cd /opt/stack/devstack/

echo "---- EXERCISE TESTS ----"
./exercise.sh

cd /opt/stack/tempest 
echo "---- TEMPEST TESTS ----"
nosetests -sv --nologcapture --attr=type=smoke tempest
END_OF_DEVSTACK_COMMANDS

END_OF_XENSERVER_COMMANDS
