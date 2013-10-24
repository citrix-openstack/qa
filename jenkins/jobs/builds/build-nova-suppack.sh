set -eux

GITREPO="$1"
DDK_ROOT_URL="$2"
GITBRANCH="$3"


# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade
sudo apt-get install -qy git rpm

# Check out rpm packaging
git clone https://github.com/citrix-openstack/xenserver-nova-suppack-builder

# Create rpm file

## Check out Nova
git clone "$GITREPO" nova
cd nova
git fetch origin "$GITBRANCH"
git checkout FETCH_HEAD
cd ..

cp -r xenserver-nova-suppack-builder/plugins/* nova/plugins/

cd nova/plugins/xenserver/xenapi/contrib
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
