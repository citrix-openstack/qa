#!/bin/bash

set -eux

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER_IP XENSERVER_PASS

A simple script to setup a XenServer installation with Quantum.

positional arguments:
 XENSERVER_IP     The IP address of the XenServer
 XENSERVER_PASS   The root password for the XenServer

An example run:

./$0 10.219.10.25 mypassword
EOF
exit 1
}

XENSERVER_IP="${1-$(print_usage_and_die)}"
XENSERVER_PASS="${2-$(print_usage_and_die)}"

ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER_IP" bash -s -- << EOF
set -exu
rm -rf devstack-ovsint
wget -qO - https://github.com/citrix-openstack/devstack/archive/ovsint.tar.gz |
    tar -xzf -
cd devstack-ovsint

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

# Tempest
DEFAULT_INSTANCE_TYPE="m1.small"

# Compute settings
EXTRA_OPTS=("xenapi_disable_agent=True")
API_RATE_LIMIT=False
VIRT_DRIVER=xenserver
XEN_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver

# Cinder settings
VOLUME_BACKING_FILE_SIZE=10000M

# Networking
MGT_IP="dhcp"

PUB_IP=172.24.4.10
PUB_NETMASK=255.255.255.0

# Expose OpenStack services on management interface
HOST_IP_IFACE=eth2

# OpenStack VM settings
OSDOMU_MEM_MB=4096
UBUNTU_INST_RELEASE=precise
UBUNTU_INST_IFACE="eth2"
OSDOMU_VDI_GB=40

# Exercise settings
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

# DevStack settings
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/
VERBOSE=False

# XenAPI specific
XENAPI_CONNECTION_URL="http://$XENSERVER_IP"
VNCSERVER_PROXYCLIENT_ADDRESS="$XENSERVER_IP"

# Custom branches
QUANTUM_REPO=https://github.com/citrix-openstack/quantum.git
QUANTUM_BRANCH=ovsint
Q_PLUGIN=openvswitch
MULTI_HOST=False
ENABLED_SERVICES+=,tempest,quantum,q-svc,q-agt,q-dhcp,q-l3,q-meta,-n-net

# Disable security groups
Q_USE_SECGROUP=False

# Workaround
os_VENDOR="Some value"

# Citrix specific settings to speed up Ubuntu install (Remove them)
UBUNTU_INST_HTTP_HOSTNAME="mirror.anl.gov"
UBUNTU_INST_HTTP_DIRECTORY="/pub/ubuntu"
UBUNTU_INST_HTTP_PROXY="http://gold.eng.hq.xensource.com:8000"

LOCALRC_CONTENT_ENDS_HERE

cd tools/xen
./install_os_domU.sh
EOF
