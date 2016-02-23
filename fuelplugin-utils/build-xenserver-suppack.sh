#!/bin/bash

set -eux

QA_REPO_ROOT=$(cd ../ && pwd)
cd $QA_REPO_ROOT
rm -rf xenserver-suppack
mkdir -p xenserver-suppack && cd xenserver-suppack


# =============================================
# Configurable items

# nova and neutron repository info
GITREPO=${1:-"https://git.openstack.org/openstack/nova"}
NEUTRON_GITREPO=${1:-"https://git.openstack.org/openstack/neutron"}
DDK_ROOT_URL=${2:-"http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz"}
GITBRANCH=${3:-"stable/liberty"}

# xenserver version info
XS_VERSION=5.6.100
XS_BUILD=39265p

# ISO info
ISO_NAME=xenserverplugins-liberty

# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive


# =============================================
# Check out rpm packaging
[ -e xenserver-nova-suppack-builder ] || git clone https://github.com/citrix-openstack/xenserver-nova-suppack-builder


# =============================================
# Create nova rpm file

if ! [ -e nova ]; then
    git clone "$GITREPO" nova
    cd nova
    git fetch origin "$GITBRANCH"
    git checkout FETCH_HEAD
    cd ..
fi

cd nova
NOVA_VER=$(
{
    grep -e "^PLUGIN_VERSION" plugins/xenserver/xenapi/etc/xapi.d/plugins/nova_plugin_version;
    echo "print PLUGIN_VERSION"
} | python
)
cd ..

cp -r xenserver-nova-suppack-builder/plugins/* nova/plugins/

cd nova/plugins/xenserver/xenapi/contrib
#./inject-key.sh ~/domzero_public_key
./build-rpm.sh
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

cp -r xenserver-nova-suppack-builder/neutron/* neutron/neutron/plugins/ml2/drivers/openvswitch/agent/xenapi/

cd neutron/neutron/plugins/ml2/drivers/openvswitch/agent/xenapi/contrib
./build-rpm.sh
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

setup(originator='xs', name='$ISO_NAME', product='XenServer',
      version=options.product_version, build=options.build, vendor='Citrix Systems, Inc.',
      description="OpenStack XenServer Plugins", packages=args, requires=[xs],
      outdir=options.outdir, output=['iso'])
EOF

sudo chroot $DDKROOT python buildscript.py \
--pdn=xenserver-plugins \
--pdv="$NOVA_VER" \
--bld=0 \
--out=/mnt/host/suppack \
/mnt/host/$RPMFILE \
/mnt/host/$NEUTRON_RPMFILE

# Cleanup
sudo umount $DDKROOT/mnt/host
sudo rm -rf "$DDKROOT"


# =============================================
# copy the packet to fuel-plugin-xenserver repoistory
# cp $QA_REPO_ROOT/xenserver-suppack/suppack/$ISO_NAME.iso \
#    $QA_REPO_ROOT/fuel-plugin-xenserver/deployment_scripts/