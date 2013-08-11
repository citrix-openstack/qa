#!/usr/bin/env bash

set -o xtrace

# setup the swap file while we are likely to get contiguous space
dd if=/dev/zero of=/var/cache/swap bs=1M count=1024
chmod 0600 /var/cache/swap
mkswap /var/cache/swap

#setup the fstab table
cat <<EOL > /etc/fstab
proc /proc proc nodev,noexec,nosuid 0 0
/dev/xvda / ext3 errors=remount-ro 0 1
/var/cache/swap none swap sw 0 0
EOL

# update installed packages and install some more base packages
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
apt-get install netbase ifupdown net-tools isc-dhcp-client grub lsb-release psmisc screen curl linux-image-`uname -r` linux-headers-`uname -r` aptitude -y --force-yes
update-grub -y

#configure the hvc0 console
sed -e "s/tty1/hvc0/g" /etc/init/tty1.conf > /etc/init/hvc0.conf
sed -i 's/root=.* ro /root=\/dev\/xvda ro console=hvc0 /g' /boot/grub/menu.lst

# setup the network
echo "ubuntu" > /etc/hostname
echo "127.0.0.1 ubuntu" >> /etc/hosts
cat <<EOL >> /etc/network/interfaces
auto eth3
iface eth3 inet dhcp
EOL
cat <<"EOL" > /etc/dhcp/dhclient-enter-hooks.d/disable-default-route
# Stop the host internal network (eth3) from supplying us with a default route
if [ "$interface" = "eth3" ]; then
    unset new_routers
fi
EOL

# resize the disk on every boot - this enables users to benefit from resizing the vdi size on reboot
cat <<EOL > /etc/init/resize2fs.conf
echo "start on mounted MOUNTPOINT=/" > /etc/init/resize2fs.conf
echo "exec /sbin/resize2fs /dev/xvda" >> /etc/init/resize2fs.conf
EOL

# Run devstack's prepare_guest.sh
cd /tmp/
cp /opt/stack/devstack/tools/xen/prepare_guest.sh ./prepare_guest.sh
sed -i".bak" '/shutdown -h now/d' ./prepare_guest.sh
mkdir -p /opt/stack/
./prepare_guest.sh xenroot ./xe-guest-utilities_6.1.0-1033_amd64.deb stack
rm ./xe-guest-utilities_6.1.0-1033_amd64.deb
rm ./prepare_guest.sh

# Create screen directory - not sure why this does not happen automatically
mkdir -p /var/run/screen
chmod 01777 /var/run/screen

# Setup devstack
cat > /opt/stack/devstack/localrc <<EOL
# Passwords
MYSQL_PASSWORD=$GUEST_PASSWORD
SERVICE_TOKEN=$GUEST_PASSWORD
ADMIN_PASSWORD=$GUEST_PASSWORD
SERVICE_PASSWORD=$GUEST_PASSWORD
RABBIT_PASSWORD=$GUEST_PASSWORD
SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"

# XenAPI parameters
# NOTE: The following must be set to your XenServer root password
XENAPI_PASSWORD=$GUEST_PASSWORD
XENAPI_CONNECTION_URL="https://169.254.0.1"
VNCSERVER_PROXYCLIENT_ADDRESS=169.254.0.1

# Do not download the usual images
IMAGE_URLS=""
# Explicitly set virt driver here
VIRT_DRIVER=xenserver
# Explicitly enable multi-host
MULTI_HOST=1
# Give extra time for boot
ACTIVE_TIMEOUT=45
USE_SCREEN=FALSE
EOL
chown stack -R /opt/stack/devstack

# Run devstack to cache sdependencies (this will fail because of the chroot)
su stack /opt/stack/run.sh
su stack /opt/stack/devstack/unstack.sh

# Finish setting up devstack
sed -i".bak" '/USE_SCREEN=FALSE/d' /opt/stack/devstack/localrc
echo 'OFFLINE=true' >> /opt/stack/devstack/localrc

# Workaround as Devstack aborts a bit to early inside the chroot
git clone https://github.com/openstack/tempest.git /opt/stack/tempest
cd /opt/stack/tempest
python setup.py develop

# Replace the apt sources with values that work for everybody 
cat <<EOL > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ precise main universe
deb http://archive.ubuntu.com/ubuntu/ precise-security main universe
deb http://archive.ubuntu.com/ubuntu/ precise-updates main universe
deb-src http://archive.ubuntu.com/ubuntu/ precise main universe
deb-src http://archive.ubuntu.com/ubuntu/ precise-security main universe
deb-src http://archive.ubuntu.com/ubuntu/ precise-updates main universe
EOL
apt-get update
apt-get clean
