#!/bin/bash

set -eux

TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)

SERVERNAME="${1-`echo 'Please specify as first parameter' && exit 5`}"

ssh $SERVERNAME << EOF
set -x
xe vm-list name-label=slave | grep -q slave && exit 0
mkdir -p /mnt/exported-vms
mount -t nfs copper.eng.hq.xensource.com:/exported-vms /mnt/exported-vms
xe vm-import filename=/mnt/exported-vms/slave.xva
umount /mnt/exported-vms
xe vm-start vm=slave
EOF
