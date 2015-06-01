#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER_IP XENSERVER_PASS

A simple script to test a XenServer devstack with Neutron on top of Citrix
changes.

positional arguments:
 XENSERVER_IP     The IP address of the XenServer
 XENSERVER_PASS   The root password for the XenServer
 GITHUB_USER      The github user to use for temporary branches

An example run:

$0 10.219.10.25 mypassword citrix-openstack
EOF
exit 1
}

XENSERVER_IP="${1-$(print_usage_and_die)}"
XENSERVER_PASS="${2-$(print_usage_and_die)}"
GITHUB_USER="${3-$(print_usage_and_die)}"

set -eux

function create_branch() {
    local source_repo
    local target_repo
    local branchname

    source_repo="$1"
    target_repo="$2"
    branchname="$3"

    local tmpdir

    tmpdir=$(mktemp -d)
    (
        cd $tmpdir
        git clone "$source_repo" repo
        cd repo
        git checkout -b "$branchname"
        git remote add target_repo "$target_repo"

        ( echo "set -exu"; cat ) | bash -s --
        git push target_repo "$branchname"
    )
    rm -rf "$tmpdir"
}

build_branch="neutron-citrix-$(date +%s)"

# Create custom devstack branch
create_branch \
    "https://github.com/openstack-dev/devstack.git" \
    "git@github.com:$GITHUB_USER/devstack.git" \
    "$build_branch" << EOF
# Use xe network-attach
git fetch https://review.openstack.org/openstack-dev/devstack refs/changes/71/35471/5 && git cherry-pick FETCH_HEAD
EOF

# # Create custom cinder branch
# create_branch \
#     "https://github.com/openstack/cinder.git" \
#     "git@github.com:$GITHUB_USER/cinder.git" \
#     "$build_branch" << EOF
# # xenapi: implement xenserver image to volume
# git fetch https://review.openstack.org/openstack/cinder refs/changes/36/34336/3 && git cherry-pick FETCH_HEAD
# EOF

# Create custom neutron branch
create_branch \
    "https://github.com/openstack/neutron.git" \
    "git@github.com:$GITHUB_USER/neutron.git" \
    "$build_branch" << EOF
# xenapi - rename quantum to neutron
git fetch https://review.openstack.org/openstack/neutron refs/changes/39/36039/2 && git cherry-pick FETCH_HEAD
EOF

ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "root@$XENSERVER_IP" bash -s -- << END_OF_XENSERVER_COMMANDS
set -exu
rm -rf "devstack-$build_branch"
wget -qO - https://github.com/$GITHUB_USER/devstack/archive/$build_branch.tar.gz |
    tar -xzf -
cd "devstack-$build_branch"

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

# Use a XenServer Image:
# IMAGE_URLS="https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz"
# DEFAULT_IMAGE_NAME="cirros-0.3.0-x86_64-disk"

# OpenStack VM settings
OSDOMU_MEM_MB=4096
OSDOMU_VDI_GB=40

# Exercise settings
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

# Increase boot timeout for neutron tests:
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
SKIP_EXERCISES="boot_from_volume"

# Quantum specific
Q_PLUGIN=openvswitch
ENABLED_SERVICES+=,tempest,neutron,q-svc,q-agt,q-dhcp,q-l3,q-meta,q-domua,-n-net

# Disable security groups
Q_USE_SECGROUP=False

# With XenServer single box install, VLANs need to be enabled
ENABLE_TENANT_VLANS="True"
OVS_VLAN_RANGES="physnet1:1000:1024"

Q_USE_DEBUG_COMMAND=True

SKIP_EXERCISES="boot_from_volume,client-env"

# Citrix specific settings to speed up Ubuntu install (Remove them)
UBUNTU_INST_HTTP_HOSTNAME="us.archive.ubuntu.com"
UBUNTU_INST_HTTP_DIRECTORY="/ubuntu"
UBUNTU_INST_HTTP_PROXY="http://gold.eng.hq.xensource.com:8000"

# Citrix settings (Remove them)
CEILOMETER_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/ceilometer.git
CEILOMETERCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-ceilometerclient.git
CINDER_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/cinder.git
CINDERCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-cinderclient.git
NOVA_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/nova.git
SWIFT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/swift.git
SWIFT3_REPO=git://gold.eng.hq.xensource.com/git/github/fujita/swift3.git
SWIFTCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-swiftclient.git
GLANCE_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/glance.git
GLANCECLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-glanceclient.git
KEYSTONE_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/keystone.git
NOVNC_REPO=git://gold.eng.hq.xensource.com/git/github/kanaka/noVNC.git
HORIZON_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/horizon.git
NOVACLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-novaclient.git
OPENSTACKCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-openstackclient.git
KEYSTONECLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-keystoneclient.git
NEUTRONCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-neutronclient.git
NEUTRON_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/neutron
TEMPEST_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/tempest.git
HEAT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/heat.git
HEATCLIENT_REPO=git://gold.eng.hq.xensource.com/git/github/openstack/python-heatclient.git
RYU_REPO=git://gold.eng.hq.xensource.com/git/github/osrg/ryu.git
BM_IMAGE_BUILD_REPO=git://gold.eng.hq.xensource.com/git/github/stackforge/diskimage-builder.git
BM_POSEUR_REPO=git://gold.eng.hq.xensource.com/git/github/tripleo/bm_poseur.git
NOVA_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/github/openstack/nova/zipball/master"
NEUTRONT_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/github/openstack/neutron/zipball/master"

# Custom branches
# CINDER_REPO=git://github.com/$GITHUB_USER/cinder.git
# CINDER_BRANCH=$build_branch

NEUTRON_REPO=git://github.com/$GITHUB_USER/neutron.git
NEUTRON_BRANCH=$build_branch
NEUTRON_ZIPBALL_URL="https://github.com/$GITHUB_USER/neutron/archive/$build_branch.zip"

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
GUEST_IP=\$(. "devstack-$build_branch/tools/xen/functions" && find_ip_by_name DevStackOSDomU 0)
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
