set -eux

XENSERVER_DDK_URL="$1"
TARGET_FILE="$2"

# Update system and install dependencies
export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get -qy upgrade

# Required packages
sudo apt-get install -qy kpartx qemu-utils

# Extract virtual disk
wget -qO ddk.iso "$XENSERVER_DDK_URL"

DDKMOUNT=$(mktemp -d)
sudo mount -o loop ddk.iso $DDKMOUNT
( for CHUNK in $DDKMOUNT/ddk/xvda/*; do zcat $CHUNK; done; ) | dd of=xvda.vhd
sudo umount "$DDKMOUNT"
rm -rf "$DDKMOUNT"

rm -f ddk.iso

# Convert to raw
qemu-img convert xvda.vhd -O raw xvda.raw
rm -f xvda.vhd

# Mount it
DDKDISKFIRSTPARTITIONDEVICE=$(sudo kpartx -av xvda.raw | cut -d" " -f 3)
DDKROOT=$(mktemp -d)
sudo mount "/dev/mapper/$DDKDISKFIRSTPARTITIONDEVICE" $DDKROOT

sudo tar -czf "$TARGET_FILE" -C "$DDKROOT" ./

sudo umount $DDKROOT
sudo kpartx -d xvda.raw
rm xvda.raw
