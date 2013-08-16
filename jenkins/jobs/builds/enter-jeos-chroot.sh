sudo mount /dev/xvdb1 /mnt/ubuntu
sudo mount /dev/ /mnt/ubuntu/dev -o bind
sudo mount none /mnt/ubuntu/dev/pts -t devpts
sudo mount none /mnt/ubuntu/proc -t proc
sudo mount none /mnt/ubuntu/sys -t sysfs

sudo cp /etc/mtab /mnt/ubuntu/etc/mtab
