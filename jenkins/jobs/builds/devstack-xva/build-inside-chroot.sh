#!/usr/bin/env bash

set -o xtrace

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install netbase ifupdown net-tools isc-dhcp-client grub lsb-release psmisc screen curl linux-image-`uname -r` linux-headers-`uname -r` aptitude -y --force-yes
apt-get upgrade -y
apt-get dist-upgrade -y
update-grub -y

sed -e "s/tty1/hvc0/g" /etc/init/tty1.conf > /etc/init/hvc0.conf
sed -i 's/root=.* ro /root=\/dev\/xvda ro console=hvc0 /g' /boot/grub/menu.lst
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

cat <<EOL > /etc/fstab
proc /proc proc nodev,noexec,nosuid 0 0
/dev/xvda / ext3 errors=remount-ro 0 1
EOL

cat <<EOL > /etc/init/resize2fs.conf
echo "start on mounted MOUNTPOINT=/" > /etc/init/resize2fs.conf
echo "exec /sbin/resize2fs /dev/xvda" >> /etc/init/resize2fs.conf 
echo "#exec rm -f /etc/init/resize2fs.conf" >> /etc/init/resize2fs.conf
EOL

cd /tmp/
# Run prepare_guest.sh
curl -o prepare_guest.sh https://raw.github.com/openstack-dev/devstack/master/tools/xen/prepare_guest.sh
sed -i".bak" '/shutdown -h now/d' prepare_guest.sh
#sed -i".bak" '/groupadd libvirtd/d' prepare_guest.sh
chmod 755 ./prepare_guest.sh
mkdir -p /opt/stack/
./prepare_guest.sh xenroot ./xe-guest-utilities_6.1.0-1033_amd64.deb stack
rm ./xe-guest-utilities_6.1.0-1033_amd64.deb
rm ./prepare_guest.sh

mkdir -p /var/run/screen
chmod 0777 /var/run/screen

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
XENAPI_PASSWORD=my_xenserver_root_password
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
chown stack /opt/stack/devstack/localrc

su stack /opt/stack/run.sh
if [ ! "$(pgrep -f /usr/local/bin/keystone-all)" ]
then
   echo "Failed to initialize Devstack but that is ok as we don't have a XenServer host to speak to."
fi
su stack /opt/stack/devstack/unstack.sh

sed -i".bak" '/USE_SCREEN=FALSE/d' /opt/stack/devstack/localrc
echo 'OFFLINE=true' >> /opt/stack/devstack/localrc

#git clone https://github.com/openstack/glance.git /opt/stack/glance
#git clone https://github.com/openstack/horizon.git /opt/stack/horizon
#git clone https://github.com/openstack/cinder.git /opt/stack/keystone
#git clone https://github.com/openstack/nova.git /opt/stack/nova
#git clone https://github.com/openstack-dev/pbr.git /opt/stack/pbr
#git clone https://github.com/openstack/python-cinderclient.git /opt/stack/python-cinderclient
#git clone https://github.com/openstack/python-glanceclient.git /opt/stack/python-glanceclient
#git clone https://github.com/openstack/python-neutronclient.git /opt/stack/python-neutronclient
#git clone https://github.com/openstack/python-heatclient.git /opt/stack/python-heatclient
#git clone https://github.com/openstack/python-keystoneclient.git /opt/stack/python-keystoneclient
#git clone https://github.com/openstack/python-neutronclient.git /opt/stack/python-neutronclient
#git clone https://github.com/openstack/python-novaclient.git /opt/stack/python-novaclient
#git clone https://github.com/openstack/python-openstackclient.git /opt/stack/python-openstackclient
#git clone https://github.com/openstack/python-swiftclient.git /opt/stack/python-swiftclient
# Workaround as Devstack aborts a bit to early inside the chroot
git clone https://github.com/openstack/tempest.git /opt/stack/tempest
cd /opt/stack/tempest
python setup.py develop

cat <<EOL > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ precise main universe
deb http://archive.ubuntu.com/ubuntu/ precise-security main universe
deb http://archive.ubuntu.com/ubuntu/ precise-updates main universe
deb-src http://archive.ubuntu.com/ubuntu/ precise main universe
deb-src http://archive.ubuntu.com/ubuntu/ precise-security main universe
deb-src http://bs.archive.ubuntu.com/ubuntu/ precise-updates main universe
EOL
apt-get update
apt-get clean
