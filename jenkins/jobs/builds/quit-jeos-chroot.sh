sudo rm /mnt/ubuntu/etc/mtab

sudo umount /mnt/ubuntu/sys
sudo umount /mnt/ubuntu/proc/xen
sudo umount /mnt/ubuntu/proc
sudo umount /mnt/ubuntu/dev/pts
sudo umount /mnt/ubuntu/dev

# Unmount
while mount | grep "/mnt/ubuntu";
do
    sudo umount /mnt/ubuntu | true
    sleep 1
done
