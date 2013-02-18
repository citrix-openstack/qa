#!/bin/bash
set -eux

mkdir -p /mnt/exported-vms
mount -t nfs copper.eng.hq.xensource.com:/exported-vms /mnt/exported-vms
xe vm-import filename=/mnt/exported-vms/slave.xva
umount /mnt/exported-vms
xe vm-start vm=slave

while ! xe vm-list name-label=slave | grep power-state | grep running;
do
    sleep 1
done
