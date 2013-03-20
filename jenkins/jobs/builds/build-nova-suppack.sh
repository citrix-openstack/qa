set -eux

GITREPO="$1"
DDK_ROOT_URL="$2"
GITBRANCH="$3"


# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade
sudo apt-get install -qy git rpm

# Create rpm file
git clone -b "$GITBRANCH" "$GITREPO"
cd nova
cd plugins/xenserver/xenapi/contrib/
./build-rpm.sh

cd
RPMFILE=$(find -name "*.noarch.rpm" -print)

# Create Supplemental pack
mkdir suppack

DDKROOT=$(mktemp -d)

wget -qO - "$DDK_ROOT_URL" | sudo tar -xzf - -C "$DDKROOT"

sudo mkdir $DDKROOT/mnt/host
sudo mount --bind $(pwd) $DDKROOT/mnt/host

sudo chroot $DDKROOT /usr/bin/build-supplemental-pack.sh \
--output=/mnt/host/suppack \
--vendor-code=novaplugin \
--vendor-name=openstack \
--label=novaplugins \
--text="nova plugins" \
--version=0 \
/mnt/host/$RPMFILE

# Cleanup
sudo umount $DDKROOT/mnt/host
sudo rm -rf "$DDKROOT"
