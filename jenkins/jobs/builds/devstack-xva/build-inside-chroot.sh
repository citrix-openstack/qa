#!/usr/bin/env bash

set -o xtrace

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install netbase ifupdown net-tools isc-dhcp-client grub lsb-release psmisc screen curl linux-image-`uname -r` linux-headers-`uname -r` -y --force-yes
apt-get upgrade -y
apt-get dist-upgrade -y
update-grub -y

sed -e "s/tty1/hvc0/g" /etc/init/tty1.conf > /etc/init/hvc0.conf
echo "ubuntu" > /etc/hostname
echo "127.0.0.1 ubuntu" >> etc/hosts
echo "proc /proc proc nodev,noexec,nosuid 0 0" > /etc/fstab
echo "/dev/xvda / ext3 errors=remount-ro 0 1" >> /etc/fstab
sed -i 's/root=.* ro /root=\/dev\/xvda ro console=hvc0 /g' /boot/grub/menu.lst

echo "start on mounted MOUNTPOINT=/" > /etc/init/resize2fs.conf
echo "exec /sbin/resize2fs /dev/xvda" >> /etc/init/resize2fs.conf 
echo "#exec rm -f /etc/init/resize2fs.conf" >> /etc/init/resize2fs.conf

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

echo ADMIN_PASSWORD=$GUEST_PASSWORD > /opt/stack/devstack/localrc
echo MYSQL_PASSWORD=$GUEST_PASSWORD >> /opt/stack/devstack/localrc
echo RABBIT_PASSWORD=$GUEST_PASSWORD >> /opt/stack/devstack/localrc
echo SERVICE_PASSWORD=$GUEST_PASSWORD >> /opt/stack/devstack/localrc
echo SERVICE_TOKEN=$GUEST_PASSWORD >> /opt/stack/devstack/localrc
echo USE_SCREEN=FALSE >> /opt/stack/devstack/localrc
echo VIRT_DRIVER=xenserver >> /opt/stack/devstack/localrc
echo XENAPI_CONNECTION_URL=https://127.0.0.1 >> /opt/stack/devstack/localrc
echo XENAPI_USER=root  >> /opt/stack/devstack/localrc
echo XENAPI_PASSWORD=password >> /opt/stack/devstack/localrc
chown stack /opt/stack/devstack/localrc
su stack /opt/stack/run.sh
if [ ! "$(pgrep -f /usr/local/bin/keystone-all)" ]
then
   echo "Failed to initialize Devstack but that is ok as we don't have a XenServer host to speak to."
fi
su stack /opt/stack/devstack/unstack.sh
sed -i".bak" '/USE_SCREEN=FALSE/d' /opt/stack/devstack/localrc
echo OFFLINE=true >> /opt/stack/devstack/localrc

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
git clone https://github.com/openstack/tempest.git /opt/stack/tempest

echo "deb http://archive.ubuntu.com/ubuntu/ precise main universe" > /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ precise-security main universe" >> /etc/apt/sources.list
echo "deb http://archive.ubuntu.com/ubuntu/ precise-updates main universe" >> /etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu/ precise main universe" >> /etc/apt/sources.list
echo "deb-src http://archive.ubuntu.com/ubuntu/ precise-security main universe" >> /etc/apt/sources.list
echo "deb-src http://bs.archive.ubuntu.com/ubuntu/ precise-updates main universe" >> /etc/apt/sources.list
apt-get update
apt-get clean
