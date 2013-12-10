HNAME="jeos"

(
cat << EOF
proc /proc proc nodev,noexec,nosuid 0 0
UUID=$(sudo blkid -s UUID /dev/xvdb1 -o value) /    ext3 errors=remount-ro 0 1
UUID=$(sudo blkid -s UUID /dev/xvdb2 -o value) none swap sw                0 0
EOF
) | sudo tee /mnt/ubuntu/etc/fstab || true 

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "grub-install /dev/xvdb"

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "update-grub"

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "apt-get clean"

sudo mkdir -p /mnt/ubuntu/root/.ssh
sudo chmod 0700 /mnt/ubuntu/root/.ssh
sudo tee /mnt/ubuntu/root/.ssh/authorized_keys << EOF
# Empty now, will be populated by /root/update_authorized_keys.sh
EOF
sudo chmod 0600 /mnt/ubuntu/root/.ssh/authorized_keys

# Install xenserver tools
sudo wget -qO /mnt/ubuntu/xstools http://downloads.vmd.citrix.com/OpenStack/xe-guest-utilities/xe-guest-utilities_6.2.0-1120_amd64.deb
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "RUNLEVEL=1 dpkg -i --no-triggers /xstools"
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "/etc/init.d/xe-linux-distribution stop"

sudo tee /mnt/ubuntu/etc/init/hvc0.conf << EOF
# hvc0 - getty
#
# This service maintains a getty on hvc0 from the point the system is
# started until it is shut down again.

start on stopped rc RUNLEVEL=[2345] and (
            not-container or
            container CONTAINER=lxc or
            container CONTAINER=lxc-libvirt)

stop on runlevel [!2345]

respawn
exec /sbin/getty -L hvc0 9600 linux
EOF

{
cat << EOF
#!/bin/bash
set -eux

DOMID=\$(xenstore-read domid)
xenstore-exists /local/domain/\$DOMID/authorized_keys/root
xenstore-read /local/domain/\$DOMID/authorized_keys/root > /root/xenstore_value
cat /root/xenstore_value > /root/.ssh/authorized_keys
EOF
} | sudo tee /mnt/ubuntu/root/update_authorized_keys.sh
sudo chmod +x /mnt/ubuntu/root/update_authorized_keys.sh

{
cat << EOF
* * * * * /root/update_authorized_keys.sh
EOF
} | sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "crontab -"

# Set hostname
echo "$HNAME" | sudo tee /mnt/ubuntu/etc/hostname

# Configure hosts file, so that hostname could be resolved
sudo sed -i "1 s/\$/ $HNAME/" /mnt/ubuntu/etc/hosts

# Disable DNS with ssh
echo "UseDNS no" | sudo tee /mnt/ubuntu/etc/ssh/sshd_config

(
cat << EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOF
) | sudo tee /mnt/ubuntu/etc/network/interfaces

{
cat << EOF
deb http://archive.ubuntu.com/ubuntu precise main
deb http://archive.ubuntu.com/ubuntu precise universe
EOF
} | sudo tee /mnt/ubuntu/etc/apt/sources.list
