USERNAME="user"
PASSWORD="simplepass"
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

# Set password for user
echo "$USERNAME:$PASSWORD" | sudo LANG=C chroot /mnt/ubuntu chpasswd

### Configure ssh keys
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "mkdir /home/$USERNAME/.ssh && \
    cat - > /home/$USERNAME/.ssh/authorized_keys && \
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh && \
    chmod 0700 /home/$USERNAME/.ssh && \
    chmod 0600 /home/$USERNAME/.ssh/authorized_keys" << EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCk6uIjjgBzz7reAtb3w9edrkSEFFhsvXZB2GaRsZZJ/Mzo5O1V/Uw7H0NgrE9yvGhlt0dEq7YIrPGpl5j3J4gsTkF65VGhOOA3q6nlNLdyHGdt0+J4h4ZztslUr0CKfga9xVDpQ0tkRe82Cs2bXuM5sb9eyEGYTz1th7KoBkwLquDksYC4P7GGDlCUgy8Bs0VzeHnh1Dj8kp0f9IUC+/4QDaTQivE61sj26H9bZ3Ea5Mm/2hxD7m7YmBLfU3asoiphoqikKB+RwJhVX0vOY6MmuNbeKBPciz3jTo15cpUlBaiYrpi8WaUzJJ+uByGVFOP02oX5Y+ioofC8Fs2tuxaj mate.lakat@citrix.com
EOF

### Enable sudo
echo "$USERNAME ALL = (ALL) ALL" | sudo tee "/mnt/ubuntu/etc/sudoers.d/allow_$USERNAME"
sudo chmod 0440 "/mnt/ubuntu/etc/sudoers.d/allow_$USERNAME"

# Install xenserver tools
sudo wget -qO /mnt/ubuntu/xstools http://downloads.vmd.citrix.com/OpenStack/xe-guest-utilities/xe-guest-utilities_6.2.0-1120_amd64.deb
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "RUNLEVEL=1 dpkg -i --no-triggers /xstools"
sudo LANG=C chroot /mnt/ubuntu /bin/bash -c \
    "/etc/init.d/xe-linux-distribution stop"

sudo cp /etc/init/hvc0.conf /mnt/ubuntu/etc/init/

# Set hostname
echo "$HNAME" | sudo tee /mnt/ubuntu/etc/hostname

# Configure hosts file, so that hostname could be resolved
sudo sed -i "1 s/\$/ $HNAME/" /mnt/ubuntu/etc/hosts

(
cat << EOF
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
EOF
) | sudo tee /mnt/ubuntu/etc/network/interfaces
