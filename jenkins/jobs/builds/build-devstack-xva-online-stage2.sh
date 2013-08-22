#/bin/bash

set -eux

XENSERVERHOST=$1
XENSERVERPASSWORD=$2

# Find out the UUID of the VM
VMUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-list name-label=DevStackOSDomU params=uuid --minimal)

# Add the host internal network
HOSTINTERNALNETWORKUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD network-list name-label=Host\ internal\ management\ network params=uuid --minimal)
HOSTINTERNALNETWORKVIFUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vif-create device=3 network-uuid=$HOSTINTERNALNETWORKUUID vm-uuid=$VMUUID) || true
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vif-plug uuid=$HOSTINTERNALNETWORKVIFUUID || true

# Find the IP of the VM
VMIP=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-param-get uuid=$VMUUID param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')

# SSH into the VM to finish the preparation
sshpass -p citrix ssh -o 'StrictHostKeyChecking no' root@$VMIP << "EOF"
set -eux

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

#Shutdown the VM
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-shutdown vm=$VMUUID

# Repackage the vhd inorder to minimize its size
SLAVEUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-list name-label=slave --minimal)
RVBDUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-list vm-uuid=$VMUUID --minimal)
RVDIUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-param-get uuid=$RVBDUUID param-name=vdi-uuid)
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-destroy uuid=$RVBDUUID || true
SLAVERVBDUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-create vm-uuid=$SLAVEUUID vdi-uuid=$RVDIUUID device=4)
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-plug uuid=$SLAVERVBDUUID
WVDIUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vdi-create sr-uuid=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vdi-list uuid=$RVDIUUID params=sr-uuid --minimal) name-label=DevStackOSDomUDisk type=system virtual-size=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vdi-list uuid=$RVDIUUID params=virtual-size --minimal))
SLAVEVWBDUUID=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-create vm-uuid=$SLAVEUUID vdi-uuid=$WVDIUUID device=5)
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-plug uuid=$SLAVEVWBDUUID
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
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-unplug uuid=$SLAVERVBDUUID
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-destroy uuid=$SLAVERVBDUUID
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-unplug uuid=$SLAVEVWBDUUID
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-destroy uuid=$SLAVEVWBDUUID
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vbd-create vm-uuid=$VMUUID vdi-uuid=$WVDIUUID device=0 bootable=true

# Export the XVA 
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-export filename=devstack.xva compress=true vm="DevStackOSDomU" include-snapshots=false

# Destroy the VM
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-destroy uuid=$VMUUID
