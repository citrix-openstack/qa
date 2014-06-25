#!/bin/bash

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
source $THISDIR/rax_functions.sh

set -eux

setup_venv `basename $0`

# Verify required parameters
[ -z ${GLOB_NODEPOOL_PASS+GLOB_NODEPOOL_PASS_unset} ] && (echo "GLOB_NODEPOOL_PASS must be set"; exit 1)
[ -z ${DIRNAME+DIRNAME_unset} ] && (echo "DIRNAME must be set to the directory (on unsteve) containing the packages"; exit 1)

# Set up nova access
pip install python-novaclient
setup_openrc ${BUILD_NUMBER:-default}.openrc citrix.nodepool2 874240 $GLOB_NODEPOOL_PASS

# Set up the keys
jenkins_key=$HOME/.ssh/id_rsa
key_name=`ssh-keygen -lf $jenkins_key.pub | cut -d ' ' -f 2 | tr -d ':'`
nova keypair-show $key_name > /dev/null || nova keypair-add --pub-key $jenkins_key.pub $key_name

#################################
# Create a VM for us to use
BUILD_VM=xs-c_deb_tester
REBUILD_VM=${REBUILD_VM:-1}
create_vm $REBUILD_VM $BUILD_VM $JESSIE_IMAGE_NAME $key_name
BUILD_IP=`nova show $BUILD_VM | grep accessIPv4 | sed -e 's/IPv4//g' -e 's/[a-z |]*//g'`

function show_target() {
    echo "Target: root@$BUILD_IP"
}
trap show_target EXIT

# DO STUFF
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
sudo sed -ie 's/mirror.rackspace.com/ftp.us.debian.org/g' /etc/apt/sources.list

# If we're running on wheezy, upgrade to jessie automatically
if \`grep -q wheezy /etc/apt/sources.list\`; then
    sudo sed -ie 's/wheezy/jessie/g' /etc/apt/sources.list
fi
sudo sed -ie '/jessie\/updates/d' /etc/apt/sources.list

apt-get -qy update
apt-get -qy upgrade
apt-get -qy install git

[ -e xenserver-core ] || git clone $REPO_URL xenserver-core
cd xenserver-core

git remote update
git reset --hard HEAD
git clean -f
git checkout $COMMIT
REMOTE_BASH_EOF

eval `ssh-agent`
ssh-add $jenkins_key
ssh-add

scp prepare_build_xsc.sh root@$BUILD_IP:
set -o pipefail
ssh root@$BUILD_IP "bash prepare_build_xsc.sh"

# Copy the RPMs over from the build cache
scp -3 -r -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$DIRNAME/RPMS \
  root@$BUILD_IP:/root/xenserver-core/RPMS

scp -3 -r -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$DIRNAME/SRPMS \
  root@$BUILD_IP:/root/xenserver-core/SRPMS

ssh root@$BUILD_IP "bash prepare_build_xsc.sh"
ssh root@$BUILD_IP "(cd xenserver-core; bash scripts/deb/install.sh)"
ssh root@$BUILD_IP "xenserver-install-wizard --yes-to-all"

ssh-agent -k
