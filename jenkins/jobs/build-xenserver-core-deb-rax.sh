#!/bin/bash

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
source $THISDIR/rax_functions.sh

setup_venv `basename $0`
# venv can't run with some of these options
set -eux

# Verify required parameters
[ -z ${GLOB_NODEPOOL_PASS+GLOB_NODEPOOL_PASS_unset} ] && (echo "GLOB_NODEPOOL_PASS must be set"; exit 1)

# Set up nova access
pip install python-novaclient
setup_openrc ${BUILD_NUMBER:-default}.openrc citrix.nodepool2 874240 $GLOB_NODEPOOL_PASS

# Set up the keys
jenkins_key=$HOME/.ssh/id_rsa
key_name=`ssh-keygen -lf $jenkins_key.pub | cut -d ' ' -f 2 | tr -d ':'`
nova keypair-show $key_name > /dev/null || nova keypair-add --pub-key $jenkins_key.pub $key_name

#################################
# Create a VM for us to use
BUILD_VM=xs-c_deb_builder
REBUILD_VM=${REBUILD_VM:-1}
create_vm $REBUILD_VM $BUILD_VM $JESSIE_IMAGE_NAME $key_name
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

REPO_URL=${REPO_URL:-https://github.com/bobball/xenserver-core.git}
COMMIT=${COMMIT:-origin/master}

cat > prepare_build_xsc.sh << REMOTE_BASH_EOF
#!/bin/bash
set -eux

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

# Rackspace's debian mirror is not very stable
sudo sed -i -e 's/mirror.rackspace.com/ftp.us.debian.org/g' /etc/apt/sources.list

# If we're running on wheezy, upgrade to jessie automatically
if \`grep -q wheezy /etc/apt/sources.list\`; then
    sudo sed -i -e 's/wheezy/jessie/g' /etc/apt/sources.list
fi
sudo sed -i -e '/jessie\/updates/d' /etc/apt/sources.list

sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get -qy install git ocaml-nox lsb-release

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
ssh root@$BUILD_IP "bash prepare_build_xsc.sh"
ssh root@$BUILD_IP "(cd xenserver-core; $args ./configure.sh 2>&1)"
ssh root@$BUILD_IP "(cd xenserver-core; $args make 2>&1)"
ssh root@$BUILD_IP "(cd xenserver-core; $args make install 2>&1)"

ssh-agent -k
