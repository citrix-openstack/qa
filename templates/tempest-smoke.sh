#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER_IP XENSERVER_PASS

A simple script to use devstack to setup an OpenStack, and run tests on it.

positional arguments:
 XENSERVER_IP     The IP address of the XenServer
 XENSERVER_PASS   The root password for the XenServer
 TEST_TYPE        Type of the tests to run. One of [none, smoke, full]
                  defaults to none

An example run on github's trunk:

$0 10.219.10.25 mypassword
EOF
exit 1
}

XENSERVER_IP="${1-$(print_usage_and_die)}"
XENSERVER_PASS="${2-$(print_usage_and_die)}"
DEVSTACK_TGZ="https://github.com/openstack-dev/devstack/archive/master.tar.gz"
TEST_TYPE="${3-none}"

set -eux

function remote_bash() {
    ssh -q \
        -o Batchmode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "root@$XENSERVER_IP" bash -s --
}

TMPDIR=$(echo "mktemp -d" | remote_bash)

remote_bash << END_OF_XENSERVER_COMMANDS
set -exu
cd $TMPDIR

wget -qO - "$DEVSTACK_TGZ" |
    tar -xzf -
cd devstack*

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

# Do not use secure delete
CINDER_SECURE_DELETE=False

# Tempest
DEFAULT_INSTANCE_TYPE="m1.tiny"

# Compute settings
EXTRA_OPTS=("xenapi_disable_agent=True")
API_RATE_LIMIT=False
VIRT_DRIVER=xenserver

# Use a XenServer Image and the standard one
# The XenServer image is faster, however tempest requires the uec files
IMAGE_URLS="\
https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz,\
http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-uec.tar.gz"

DEFAULT_IMAGE_NAME="cirros-0.3.0-x86_64-disk"

# OpenStack VM settings
# OSDOMU_MEM_MB=4096
OSDOMU_VDI_GB=40

# Exercise settings
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

# Increase boot timeout for neutron tests:
BOOT_TIMEOUT=500

# DevStack settings
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/
#VERBOSE=True

# XenAPI specific
XENAPI_CONNECTION_URL="http://$XENSERVER_IP"
VNCSERVER_PROXYCLIENT_ADDRESS="$XENSERVER_IP"

MULTI_HOST=1

# Skip boot from volume exercise
SKIP_EXERCISES="boot_from_volume"

ENABLED_SERVICES=g-api,g-reg,key,n-api,n-crt,n-obj,n-cpu,n-sch,horizon,mysql,rabbit,sysstat,tempest,s-proxy,s-account,s-container,s-object,cinder,c-api,c-vol,c-sch,n-cond,heat,h-api,h-api-cfn,h-api-cw,h-eng,n-net

# XEN_FIREWALL_DRIVER=nova.virt.xenapi.firewall.Dom0IptablesFirewallDriver
XEN_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver

# 9 Gigabyte for object store
SWIFT_LOOPBACK_DISK_SIZE=9000000

# Additional Localrc parameters here

LOCALRC_CONTENT_ENDS_HERE

cd tools/xen
./install_os_domU.sh
END_OF_XENSERVER_COMMANDS

if [ "$TEST_TYPE" == "none" ]; then
    exit 0
fi

# Run tests
remote_bash << END_OF_XENSERVER_COMMANDS
set -exu
cd $TMPDIR
cd devstack*

GUEST_IP=\$(. "tools/xen/functions" && find_ip_by_name DevStackOSDomU 0)
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "stack@\$GUEST_IP" bash -s -- << END_OF_DEVSTACK_COMMANDS
set -exu

cd /opt/stack/devstack/
./exercise.sh

cd /opt/stack/tempest 
if [ "$TEST_TYPE" == "smoke" ]; then
    nosetests -sv --nologcapture --attr=type=smoke tempest
elif [ "$TEST_TYPE" == "full" ]; then
    nosetests -sv tempest/api tempest/scenario tempest/thirdparty tempest/cli
fi

END_OF_DEVSTACK_COMMANDS

END_OF_XENSERVER_COMMANDS
