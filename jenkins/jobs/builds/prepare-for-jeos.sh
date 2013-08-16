set -eux

# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade

# Partition xvdb
(
cat << EOF
o
n
p


+8G
t
83
n
p



t
2
82
wq
EOF
) | sudo fdisk /dev/xvdb

sudo partprobe /dev/xvdb

sudo mkfs.ext3 /dev/xvdb1
sudo mkswap /dev/xvdb2
sync

sudo mkdir -p /mnt/ubuntu
sudo mount /dev/xvdb1 /mnt/ubuntu

sudo apt-get install -qy debootstrap
sudo http_proxy=http://gold.eng.hq.xensource.com:8000 debootstrap \
     --arch=amd64 \
     precise \
     /mnt/ubuntu \
     http://mirror.anl.gov/pub/ubuntu/

# Unmount
while mount | grep "/mnt/ubuntu";
do
    sudo umount /mnt/ubuntu | true
    sleep 1
done
