#!/bin/bash
set -eux

if [ -z "$(xe snapshot-list name-label=slave-fresh --minimal)" ]
then
    xe vm-uninstall vm=slave force=true || true
    mkdir -p /mnt/exported-vms

    mount -t nfs copper.eng.hq.xensource.com:/exported-vms /mnt/exported-vms
    VM=$(xe vm-import filename=/mnt/exported-vms/slave.xva)
    umount /mnt/exported-vms

    xe vm-snapshot vm=slave new-name-label=slave-fresh > /dev/null
fi

SNAP=$(xe snapshot-list name-label=slave-fresh --minimal)
xe snapshot-revert snapshot-uuid=$SNAP

VM=$(xe vm-list name-label=slave --minimal)

xe vm-start vm=slave

while [ "$(xe vm-param-get uuid=$VM param-name=power-state)" != "running" ];
do
    sleep 1
done

while true
do
    SLAVE_IP=$(xe vm-param-get uuid=$VM param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
    [ -z "$SLAVE_IP" ] || { echo "$SLAVE_IP"; exit 0; }
    sleep 1
done
