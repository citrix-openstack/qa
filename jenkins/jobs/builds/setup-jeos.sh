USERNAME="user"
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

# Add a user
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "DEBIAN_FRONTEND=noninteractive \
    adduser --disabled-password --quiet $USERNAME --gecos $USERNAME"

### Configure ssh keys
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "mkdir /home/$USERNAME/.ssh && \
    cat - > /home/$USERNAME/.ssh/authorized_keys && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && \
    chmod 0700 /home/$USERNAME/.ssh && \
    chmod 0600 /home/$USERNAME/.ssh/authorized_keys" << EOF
# Empty now, will be populated by /root/update_authorized_keys.sh
EOF

### Enable sudo
echo "$USERNAME ALL = NOPASSWD: ALL" | sudo tee "/mnt/ubuntu/etc/sudoers.d/allow_$USERNAME"
sudo chmod 0440 "/mnt/ubuntu/etc/sudoers.d/allow_$USERNAME"

# Install xenserver tools
sudo wget -qO /mnt/ubuntu/xstools http://downloads.vmd.citrix.com/OpenStack/xe-guest-utilities/xe-guest-utilities_6.2.0-1120_amd64.deb
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "RUNLEVEL=1 dpkg -i --no-triggers /xstools"
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "/etc/init.d/xe-linux-distribution stop"

sudo cp /etc/init/hvc0.conf /mnt/ubuntu/etc/init/

{
cat << EOF
#!/bin/bash
set -eux

DOMID=\$(xenstore-read domid)
xenstore-exists /local/domain/\$DOMID/authorized_keys/$USERNAME
xenstore-read /local/domain/\$DOMID/authorized_keys/$USERNAME > /home/$USERNAME/xenstore_value
cat /home/$USERNAME/xenstore_value > /home/$USERNAME/.ssh/authorized_keys
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
