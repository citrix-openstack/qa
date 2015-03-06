#/bin/bash

set -eux

XENSERVERHOST=$1
XENSERVERPASSWORD=$2

function xecommand() {
    sshpass -p $XENSERVERPASSWORD ssh -o 'StrictHostKeyChecking no' root@$XENSERVERHOST "xe $@"
}

# Find out the UUID of the VM
VMUUID=$(xecommand vm-list name-label=DevStackOSDomU params=uuid --minimal)

# Add the host internal network
HOSTINTERNALNETWORKUUID=$(xecommand network-list bridge=xenapi params=uuid --minimal)
[ -n "$HOSTINTERNALNETWORKUUID" ]
HOSTINTERNALNETWORKVIFUUID=$(xecommand vif-create device=3 network-uuid=$HOSTINTERNALNETWORKUUID vm-uuid=$VMUUID)
[ -n "$HOSTINTERNALNETWORKVIFUUID" ]
xecommand vif-plug uuid=$HOSTINTERNALNETWORKVIFUUID

# Find the IP of the VM
VMIP=$(xecommand vm-param-get uuid=$VMUUID param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')

# Enable root login
sshpass -p citrix ssh -o 'StrictHostKeyChecking no' stack@$VMIP << "EOF"
set -eux
sudo sed -i -e 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo restart ssh
sleep 5
EOF

# SSH into the VM to finish the preparation
sshpass -p citrix ssh -o 'StrictHostKeyChecking no' root@$VMIP << "EOF"
set -eux

# Get rid of domzero's keys
rm -f /home/domzero/.ssh/authorized_keys /home/domzero/.ssh/id_rsa /home/domzero/.ssh/id_rsa.pub

# Generate a new key for domzero
su -c "ssh-keygen -f /home/domzero/.ssh/id_rsa -C domzero@appliance -N '' -q" domzero

#stop Devstack
#su stack /opt/stack/devstack/unstack.sh || true

# setup the network
cat <<"EOL" >> /etc/network/interfaces
auto eth3
iface eth3 inet dhcp
EOL
echo "127.0.0.1 `hostname`" >> /etc/hosts
cat <<"EOL" > /etc/dhcp/dhclient-enter-hooks.d/disable-default-route
# Stop the host internal network (eth3) from supplying us with a default route
if [ "$interface" = "eth3" ]; then
    unset new_routers
fi
EOL

#setup devstack
sed -i '/XENAPI_CONNECTION_URL/d' /opt/stack/devstack/localrc
sed -i '/VNCSERVER_PROXYCLIENT_ADDRESS/d' /opt/stack/devstack/localrc
sed -i '/XENAPI_PASSWORD/d' /opt/stack/devstack/localrc
sed -i '/VERBOSE/d' /opt/stack/devstack/localrc
cat <<"EOL" >> /opt/stack/devstack/localrc
XENAPI_CONNECTION_URL="https://169.254.0.1"
VNCSERVER_PROXYCLIENT_ADDRESS=169.254.0.1

OFFLINE=true
VERBOSE=true
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

# Save domzero's public key to local filesystem
sshpass -p citrix scp -o 'StrictHostKeyChecking no' root@$VMIP:/home/domzero/.ssh/id_rsa.pub ~/domzero_public_key

#Shutdown the VM
xecommand vm-shutdown vm=$VMUUID

# Repackage the vhd in order to minimize its size
SLAVEUUID=$(xecommand vm-list name-label=slave --minimal)
RVBDUUID=$(xecommand vbd-list vm-uuid=$VMUUID device=xvda --minimal)
RVDIUUID=$(xecommand vbd-param-get uuid=$RVBDUUID param-name=vdi-uuid)
xecommand vbd-destroy uuid=$RVBDUUID || true
SLAVERVBDUUID=$(xecommand vbd-create vm-uuid=$SLAVEUUID vdi-uuid=$RVDIUUID device=4)
xecommand vbd-plug uuid=$SLAVERVBDUUID
WVDIUUID=$(xecommand vdi-create sr-uuid=$(xecommand vdi-list uuid=$RVDIUUID params=sr-uuid --minimal) name-label=DevStackOSDomUDisk type=system virtual-size=$(xecommand vdi-list uuid=$RVDIUUID params=virtual-size --minimal))
SLAVEVWBDUUID=$(xecommand vbd-create vm-uuid=$SLAVEUUID vdi-uuid=$WVDIUUID device=5)
xecommand vbd-plug uuid=$SLAVEVWBDUUID
sudo sfdisk -d /dev/xvde | sudo sfdisk /dev/xvdf
sudo dd if=/dev/xvde of=/dev/xvdf bs=446 count=1
mkdir xvde1
sudo mount /dev/xvde1 xvde1
sudo mkfs.ext4 /dev/xvdf1
mkdir xvdf1
sudo mount /dev/xvdf1 xvdf1
sudo cp -ax xvde1/* xvdf1/
sudo umount xvde1
sudo umount xvdf1
rmdir xvde1
rmdir xvdf1
ROOTUUID=$(sudo blkid /dev/xvde1 | awk '{ print $2 }' | sed 's/UUID="//g' | sed 's/"//g')
SWAPUUID=$(sudo blkid /dev/xvde5 | awk '{ print $2 }' | sed 's/UUID="//g' | sed 's/"//g')
sudo tune2fs /dev/xvdf1 -U $ROOTUUID
sudo mkswap -U $SWAPUUID /dev/xvdf5
xecommand vbd-unplug uuid=$SLAVERVBDUUID
xecommand vbd-destroy uuid=$SLAVERVBDUUID
xecommand vbd-unplug uuid=$SLAVEVWBDUUID
xecommand vbd-destroy uuid=$SLAVEVWBDUUID
xecommand vbd-create vm-uuid=$VMUUID vdi-uuid=$WVDIUUID device=0 bootable=true

# Re-create XVDB
CINDER_VBD=$(xecommand vbd-list vm-name-label=DevStackOSDomU device=xvdb --minimal)

if [ -n "$CINDER_VBD" ]; then
    vdi=$(xecommand vbd-param-get param-name=vdi-uuid uuid=$CINDER_VBD)
    virtual_size=$(xecommand vdi-param-get param-name=virtual-size uuid=$vdi --minimal)
    localsr=$(xecommand vdi-param-get param-name=sr-uuid uuid=$vdi --minimal)
    xecommand vbd-destroy uuid=$CINDER_VBD
    xecommand vdi-destroy uuid=$vdi
    vdi=$(xecommand vdi-create \
        name-label=CinderVolumes \
        virtual-size=$virtual_size \
        sr-uuid=$localsr \
        type=user)
    xecommand vbd-create vm-uuid=$VMUUID vdi-uuid=$vdi device=1
fi

# Export the XVA
xecommand vm-export filename=devstack_original.xva compress=true vm="DevStackOSDomU" include-snapshots=false

# Rename bridges (takes a long time)
wget -q "https://raw.github.com/citrix-openstack/qa/master/jenkins/jobs/xva-rename-bridges.py"
python xva-rename-bridges.py devstack_original.xva devstack.xva
rm -f devstack_original.xva

echo "Devstack XVA ready"
ls -lah devstack.xva

# Destroy the VM
xecommand vm-destroy uuid=$VMUUID
