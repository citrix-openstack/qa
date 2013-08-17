#/bin/bash

set -eux

XENSERVERHOST=$1
XENSERVERPASSWORD=$2

TEMPKEYFILE=$(mktemp)

# Prepare slave requirements
sudo apt-get install xcp-xe stunnel

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
./install-devstack-xen.sh $TEMPKEYFILE $XENSERVERHOST $XENSERVERPASSWORD || true

# Find out the UUID of the VM
VMUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-list name-label=DevStackOSDomU params=uuid --minimal)

# Add the host internal network
HOSTINTERNALNETWORKUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD network-list name-label=Host\ internal\ management\ network params=uuid --minimal)
HOSTINTERNALNETWORKVIFUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vif-create device=3 network-uuid=$HOSTINTERNALNETWORKUUID vm-uuid=$VMUUID) || true
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vif-plug uuid=$HOSTINTERNALNETWORKVIFUUID || true

# Find the IP of the VM
VMIP=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-param-get uuid=$VMUUID param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')

# SSH into the VM to finish the preparation
ssh -i $TEMPKEYFILE -o 'StrictHostKeyChecking no' root@$VMIP << "EOF"
#stop Devstack
su stack /opt/stack/devstack/unstack.sh

# setup the network
cat <<EOL >> /etc/network/interfaces
auto eth3
iface eth3 inet dhcp
EOL
echo "127.0.0.1 $GUEST_NAME" >> /etc/hosts
cat <<"EOL" > /etc/dhcp/dhclient-enter-hooks.d/disable-default-route
# Stop the host internal network (eth3) from supplying us with a default route
if [ "$interface" = "eth3" ]; then
    unset new_routers
fi
EOL

#setup devstack
sed -i '/XENAPI_CONNECTION_URL/d' /opt/stack/devstack/localrc
sed -i '/VNCSERVER_PROXYCLIENT_ADDRESS/d' /opt/stack/devstack/localrc
cat <<"EOL" >> /opt/stack/devstack/localrc
XENAPI_CONNECTION_URL="https://169.254.0.1"
VNCSERVER_PROXYCLIENT_ADDRESS=169.254.0.1

OFFLINE=true
EOL

# clean-up startup (ToDo: this should be fixed in devstack)
sed -i '/# network restart required for getting the right gateway/d' /etc/rc.local
sed -i '/\/etc\/init.d\/networking restart/d' /etc/rc.local

# tidy up
rm -rf /tmp/*
rm -rf /opt/stack/.ssh
apt-get clean
rm ~/xs-tools.deb || true
EOF

# Get a copy of Nova for building the Suppack
scp -r -i $TEMPKEYFILE -o 'StrictHostKeyChecking no' root@$VMIP:/opt/stack/nova ./

#Shutdown the VM
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-shutdown vm=$VMUUID

# Export the XVA 
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-export filename=devstack.xva compress=true vm="DevStackOSDomU" include-snapshots=false

# Destroy the VM
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-destroy uuid=$VMUUID
