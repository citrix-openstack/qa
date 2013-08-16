(
cat << EOF
proc /proc proc nodev,noexec,nosuid 0 0
UUID=$(sudo blkid -s UUID /dev/xvdb1 -o value) /    ext3 errors=remount-ro 0 1
UUID=$(sudo blkid -s UUID /dev/xvdb2 -o value) none swap sw                0 0
EOF
) | sudo tee /mnt/ubuntu/etc/fstab || true 

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "http_proxy=http://gold.eng.hq.xensource.com:8000 \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -qy language-pack-en"
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "http_proxy=http://gold.eng.hq.xensource.com:8000 \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -qy linux-image-virtual"

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "grub-install /dev/xvdb"

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "update-grub"

sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "apt-get clean"

# Install xenserver tools
sudo wget -qO /mnt/ubuntu/xstools https://github.com/downloads/citrix-openstack/warehouse/xe-guest-utilities_6.1.0-1033_amd64.deb
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "RUNLEVEL=1 dpkg -i --no-triggers /xstools"
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "/etc/init.d/xe-linux-distribution stop"

sudo cp /etc/init/hvc0.conf /mnt/ubuntu/etc/init/

# Set hostname
echo "jeos" | sudo tee /mnt/ubuntu/etc/hostname

(
cat << EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOF
) | sudo tee /mnt/ubuntu/etc/network/interfaces
