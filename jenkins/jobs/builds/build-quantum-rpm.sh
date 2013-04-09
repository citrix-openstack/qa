set -eux

GITREPO="$1"
GITBRANCH="$2"
DDK_ROOT_URL="$3"


# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade
sudo apt-get install -qy git rpm

# Create rpm file
git clone "$GITREPO" -b "$GITBRANCH" quantum

# Download epel rpm


# Extract ddk
DDKROOT=$(mktemp -d)

wget -qO - "$DDK_ROOT_URL" | sudo tar -xzf - -C "$DDKROOT"

sudo mkdir $DDKROOT/mnt/host
sudo mount --bind $(pwd) $DDKROOT/mnt/host
sudo mount --bind /dev $DDKROOT/dev

# Setup name resolution inside the jail
sudo cp /etc/resolv.conf $DDKROOT/etc/resolv.conf

# Download packages
wget -q http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm

# Install epel
setarch i386 sudo chroot $DDKROOT sh -c "cd /mnt/host/ && \
    rpm -Uvh epel-release-5-4.noarch.rpm"

# Install git (git required for getting the version)
setarch i386 sudo chroot $DDKROOT sh -c "\
    yum --enablerepo=epel -qy install git"

# Install python 2.6 with distribute (distribute required for getting the ver)
setarch i386 sudo chroot $DDKROOT sh -c "\
    yum --enablerepo=epel -qy install python26-distribute"

# Create agent
setarch i386 sudo chroot $DDKROOT sh -c "\
    cd /mnt/host/quantum/quantum/plugins/openvswitch && \
    make agent-dist-xen-python26"

# Putting all rpms to one directory
mkdir -p rpms
find quantum -name "ovs-quantum-agent-*" -name "*.noarch.rpm" -exec cp {} rpms/ \;

(
cd rpms
wget -q http://dl.fedoraproject.org/pub/epel/5/i386/python26-2.6.8-2.el5.i386.rpm
wget -q http://dl.fedoraproject.org/pub/epel/5/i386/libffi-3.0.5-1.el5.i386.rpm
wget -q http://dl.fedoraproject.org/pub/epel/5/i386/python26-libs-2.6.8-2.el5.i386.rpm
wget -q http://dl.fedoraproject.org/pub/epel/5/i386/python26-distribute-0.6.10-4.el5.noarch.rpm
)

mkdir suppack
sudo chroot $DDKROOT sh -c "/usr/bin/build-supplemental-pack.sh \
--output=/mnt/host/suppack \
--vendor-code=novaplugin \
--vendor-name=openstack \
--label=novaplugins \
--text=novaplugins \
--version=0 \
/mnt/host/rpms/libffi-3.0.5-1.el5.i386.rpm \
/mnt/host/rpms/ovs-quantum-agent-2013.1-1.noarch.rpm \
/mnt/host/rpms/python26-2.6.8-2.el5.i386.rpm \
/mnt/host/rpms/python26-distribute-0.6.10-4.el5.noarch.rpm \
/mnt/host/rpms/python26-libs-2.6.8-2.el5.i386.rpm"

exit 0
# Cleanup
sudo umount $DDKROOT/dev
sudo umount $DDKROOT/mnt/host
sudo rm -rf "$DDKROOT"
