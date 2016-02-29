#!/bin/bash

set -eux

# =============================================
# Usage of this script:
# ./build-xenserver-suppack.sh xs-version xs-build git-branch plugin-version
# or
# ./build-xenserver-suppack.sh
#
# You can provide explict input parameters or you can use the default ones:
#   XenServer version
#   XenServer build
#   OpenStack release branch
#   XenServer OpenStack plugin version


QA_REPO_ROOT=$(cd ../ && pwd)
cd $QA_REPO_ROOT
rm -rf xenserver-suppack
mkdir -p xenserver-suppack && cd xenserver-suppack


# =============================================
# Configurable items

# xenserver version info
XS_VERSION=${1:-"6.2"}
XS_BUILD=${2:-"70446c"}

# branch info
GITBRANCH=${3:-"stable/liberty"}

# nova and neutron xenserver dom0 plugin version
XS_PLUGIN_VERSION=${4:-"2012.1"}

# OpenStack release
OS_RELEASE=liberty

# repository info
NOVA_GITREPO="https://git.openstack.org/openstack/nova"
NEUTRON_GITREPO="https://git.openstack.org/openstack/neutron"
DDK_ROOT_URL="http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz"

# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive


# =============================================
# Check out rpm packaging repo
if ! [ -e xenserver-nova-suppack-builder ]; then
    git clone https://github.com/citrix-openstack/xenserver-nova-suppack-builder
fi


# =============================================
# Create nova rpm file

if ! [ -e nova ]; then
    git clone "$NOVA_GITREPO" nova
    cd nova
    git fetch origin "$GITBRANCH"
    git checkout FETCH_HEAD
    cd ..
fi

cp -r xenserver-nova-suppack-builder/plugins/xenserver/xenapi/* nova/plugins/xenserver/xenapi/
cd nova/plugins/xenserver/xenapi/contrib
./build-rpm.sh $XS_PLUGIN_VERSION
cd $QA_REPO_ROOT/xenserver-suppack/
RPMFILE=$(find -name "openstack-xen-plugins-*.noarch.rpm" -print)


# =============================================
# Create neutron rpm file

if ! [ -e neutron ]; then
    git clone "$NEUTRON_GITREPO" neutron
    cd neutron
    git fetch origin "$GITBRANCH"
    git checkout FETCH_HEAD
    cd ..
fi

rm -rf neutron/neutron/plugins/ml2/drivers/openvswitch/agent/xenapi/contrib
cp -r xenserver-nova-suppack-builder/neutron/* \
      neutron/neutron/plugins/ml2/drivers/openvswitch/agent/xenapi/
cd neutron/neutron/plugins/ml2/drivers/openvswitch/agent/xenapi/contrib
./build-rpm.sh $XS_PLUGIN_VERSION
cd $QA_REPO_ROOT/xenserver-suppack/
NEUTRON_RPMFILE=$(find -name "openstack-neutron-xen-plugins-*.noarch.rpm" -print)


# =============================================
# Create Supplemental pack
rm -rf suppack
mkdir suppack

DDKROOT=$(mktemp -d)

wget -qO - "$DDK_ROOT_URL" | sudo tar -xzf - -C "$DDKROOT"

sudo mkdir $DDKROOT/mnt/host
sudo mount --bind $(pwd) $DDKROOT/mnt/host

sudo tee $DDKROOT/buildscript.py << EOF
from xcp.supplementalpack import *
from optparse import OptionParser

parser = OptionParser()
parser.add_option('--pdn', dest="product_name")
parser.add_option('--pdv', dest="product_version")
parser.add_option('--bld', dest="build")
parser.add_option('--out', dest="outdir")
(options, args) = parser.parse_args()

xs = Requires(originator='xs', name='main', test='ge',
               product='XenServer', version='$XS_VERSION',
               build='$XS_BUILD')

setup(originator='xs', name='xenserverplugins-$OS_RELEASE', product='XenServer',
      version=options.product_version, build=options.build, vendor='Citrix Systems, Inc.',
      description="OpenStack XenServer Plugins", packages=args, requires=[xs],
      outdir=options.outdir, output=['iso'])
EOF

sudo chroot $DDKROOT python buildscript.py \
--pdn=xenserverplugins \
--pdv=$OS_RELEASE \
--bld=0 \
--out=/mnt/host/suppack \
/mnt/host/$RPMFILE \
/mnt/host/$NEUTRON_RPMFILE

# Cleanup
sudo umount $DDKROOT/mnt/host
sudo rm -rf "$DDKROOT"
