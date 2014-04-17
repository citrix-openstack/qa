#!/bin/bash

if [ -z ${BUILD_NUMBER+BUILD_NUMBER_unset} ]; then
    # Assume we're not running in jenkins - move to a scratch location
    [ -e /tmp/xenserver-core-deb ] &&  rm -rf /tmp/xenserver-core-deb/*
    mkdir -p /tmp/xenserver-core-deb
    cd /tmp/xenserver-core-deb
fi

set -ex

# Set up virtual environment
[ -e .env ] || virtualenv .env
. .env/bin/activate
pip install --upgrade pip

# Verify required parameters
[ -z ${GLOB_NODEPOOL_PASS+GLOB_NODEPOOL_PASS_unset} ] && (echo "GLOB_NODEPOOL_PASS must be set"; exit 1)
set -u

openrc=${BUILD_NUMBER:-default}.openrc
cat > $openrc << BASH_PROFILE
export OS_AUTH_URL=https://identity.api.rackspacecloud.com/v2.0/
export OS_REGION_NAME=IAD
export OS_AUTH_SYSTEM=keystone
export OS_USERNAME=citrix.nodepool2
export OS_TENANT_NAME=874240
export OS_PASSWORD=$GLOB_NODEPOOL_PASS
export OS_PROJECT_ID=874240
export OS_NO_CACHE=1
BASH_PROFILE

REPO_URL=${REPO_URL:-https://github.com/bobball/xenserver-core.git}
COMMIT=${COMMIT:-origin/master}

JESSIE_IMAGE_NAME=8025a161-aaaf-4568-a014-408d6aed00ba

[ -e remote-bash ] || git clone https://github.com/citrix-openstack/remote-bash
for dir in remote-bash; do
  ( cd $dir; git pull; )
done
export PATH=$PATH:$(pwd)/remote-bash/bin

# Set up nova access
pip install python-novaclient

# Don't trace the openrc as it includes a password!
set +x
source $openrc
set -x

# Set up the keys
jenkins_key=$HOME/.ssh/id_rsa
key_name=`ssh-keygen -lf $jenkins_key.pub | cut -d ' ' -f 2 | tr -d ':'`
nova keypair-show $key_name || nova keypair-add --pub-key $jenkins_key.pub $key_name

# Verify that the jessie image exists
set +e
nova image-show $JESSIE_IMAGE_NAME > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Jessie image $JESSIE_IMAGE_NAME not seen in region $OS_REGION_NAME"
    exit 1
fi
set -e

#################################
# Create a VM for us to use
BUILD_VM=xs-c_deb_builder
REBUILD_VM=1
if [ $REBUILD_VM -gt 0 ]; then
    set +e
    nova show $BUILD_VM
    if [ $? -eq 0 ]; then
	nova delete $BUILD_VM
	COUNTER=0
	while `nova show $BUILD_VM > /dev/null 2>&1`; do
	    echo "Waiting for $BUILD_VM to be destroyed..."
	    sleep 10
	    let COUNTER=COUNTER+1
	    if [ $COUNTER -gt 20 ]; then
		echo "Timed out waiting for VM $BUILD_VM to be destroyed"
		exit 1
	    fi
	done
    fi
    set -e

    nova boot --poll --flavor performance1-1 --image $JESSIE_IMAGE_NAME --key-name $key_name $BUILD_VM
fi
BUILD_IP=`nova show $BUILD_VM | grep accessIPv4 | sed -e 's/IPv4//g' -e 's/[a-z |]*//g'`

function show_target() {
    echo "Target: root@$BUILD_IP"
}
trap show_target EXIT

eval `ssh-agent`
ssh-add $jenkins_key

DIST="jessie"
args="DIST=$DIST"
args="$args MIRROR=http://ftp.us.debian.org/debian/"
args="$args APT_REPOS='|deb @MIRROR@ @DIST@ contrib |deb @MIRROR@ @DIST@-backports main '"

cat > prepare_build_xsc.sh << REMOTE_BASH_EOF
#!/bin/bash
set -eux

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

# Rackspace's debian mirror is not very stable
sudo sed -ie 's/mirror.rackspace.com/ftp.us.debian.org/g' /etc/apt/sources.list

# If we're running on wheezy, upgrade to jessie automatically
if \`grep -q wheezy /etc/apt/sources.list\`; then
    sudo sed -ie 's/wheezy/jessie/g' /etc/apt/sources.list
    sudo sed -ie '/jessie\/updates/d' /etc/apt/sources.list
fi

sudo apt-get update
sudo apt-get -y dist-upgrade
sudo apt-get -y install git ocaml-nox lsb-release

[ -e xenserver-core ] || git clone $REPO_URL xenserver-core
cd xenserver-core

git remote update
git reset --hard HEAD
git clean -f
git checkout $COMMIT

cat >> scripts/deb/templates/pbuilderrc << PBUILDERRC
#export http_proxy=http://gold.eng.hq.xensource.com:8000
DEBOOTSTRAPOPTS=--no-check-gpg
PBUILDERRC

cat >> scripts/deb/templates/D04backports << BACKPORTS_HOOK
echo "I: Pinning repositories"
tee /etc/apt/preferences.d/50backports << APT_PIN_BACKPORTS
Package: *
Pin: release a=$DIST-backports
Pin-Priority: 600
APT_PIN_BACKPORTS
tee /etc/apt/preferences.d/60local << APT_PIN_LOCAL
Package: *
Pin: origin ""
Pin-Priority: 600
APT_PIN_LOCAL
BACKPORTS_HOOK
cp scripts/deb/templates/D04backports scripts/deb/templates/F04backports
REMOTE_BASH_EOF

scp prepare_build_xsc.sh root@$BUILD_IP:
set -o pipefail
ssh root@$BUILD_IP "bash prepare_build_xsc.sh" | tee configure.log
ssh root@$BUILD_IP "(cd xenserver-core; $args ./configure.sh 2>&1)" | tee -a configure.log
ssh root@$BUILD_IP "(cd xenserver-core; $args make 2>&1)" | tee make.log
