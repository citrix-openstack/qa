set -eux

# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade
sudo apt-get install -qy git

# Create suppack
GITREPO="$1"
git clone "$GITREPO"
cd nova
cd plugins/xenserver/xenapi/contrib/
./build-rpm.sh
