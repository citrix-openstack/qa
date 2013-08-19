#/bin/bash

set -eux

XENSERVERHOST=$1
XENSERVERPASSWORD=$2

TEMPKEYFILE=$(mktemp)

# Prepare slave requirements
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install xcp-xe stunnel sshpass

rm -f install-devstack-xen.sh || true
wget https://raw.github.com/citrix-openstack/qa/master/install-devstack-xen.sh
sed -i '/# Use a combination of openstack master and citrix-openstack citrix-fixes/d' install-devstack-xen.sh
sed -i '/# May not be instantly up to date with openstack master/d' install-devstack-xen.sh
sed -i 's/OSDOMU_VDI_GB=40/OSDOMU_VDI_GB=10/g' install-devstack-xen.sh
sed -i '/NOVA_REPO/d' install-devstack-xen.sh
sed -i '/NOVA_BRANCH/d' install-devstack-xen.sh
chmod 755 install-devstack-xen.sh
rm -f $TEMPKEYFILE
ssh-keygen -t rsa -N "" -f $TEMPKEYFILE
echo "StrictHostKeyChecking no" > ~/.ssh/config
sshpass -p $XENSERVERPASSWORD ssh-copy-id -i $TEMPKEYFILE.pub root@$XENSERVERHOST
rm -f ~/.ssh/config
./install-devstack-xen.sh $TEMPKEYFILE $XENSERVERHOST $XENSERVERPASSWORD || true
