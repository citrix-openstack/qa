#!/bin/bash

set -eux

XENSERVER="$1"
XENSERVER_PASSWORD="$2"

DEVSTACK_NAME="DevStackOSDomU"

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
. "$THISDIR/functions.sh"

WORKER=$(run_bash_script_on "root@$XENSERVER" "$THISDIR/xslib/get-worker.sh")

remote_bash "root@$XENSERVER" << EOF
set -eux
DEVSTACK=\$(xe vm-list name-label=$DEVSTACK_NAME --minimal)
if [ "halted" != "\$(xe vm-param-get param-name=power-state uuid=\$DEVSTACK)" ]; then
    xe vm-shutdown uuid=\$DEVSTACK
fi

ROOT_VBD=\$(xe vbd-list vm-uuid=\$DEVSTACK userdevice=0 --minimal)
ROOT_VDI=\$(xe vbd-param-get param-name=vdi-uuid uuid=\$ROOT_VBD)

SLAVE=\$(xe vm-list name-label=slave --minimal)

SLAVE_VBD=\$(xe vbd-create vm-uuid=\$SLAVE vdi-uuid=\$ROOT_VDI device=1)

xe vbd-plug uuid=\$SLAVE_VBD
EOF

remote_bash $WORKER << EOF
sudo fdisk -l /dev/xvdb
sudo mkdir -p /mnt/devstackroot
sudo mount /dev/xvdb1 /mnt/devstackroot

cat >> /mnt/devstackroot/opt/stack/devstack/localrc << LOCALRC
XENAPI_PASSWORD=$XENSERVER_PASSWORD
LOCALRC

sudo cat /mnt/devstackroot/home/domzero/.ssh/id_rsa.pub > domzero_pubkey.pub

# sudo dd if=/dev/zero of=/mnt/devstackroot/zeroes bs=100M
# sudo rm /mnt/devstackroot/zeroes

df -h

while ! sudo umount /mnt/devstackroot/; do
    sleep 1
done

exit 0
EOF

echo "cat domzero_pubkey.pub" | remote_bash $WORKER > domzero_pubkey

DOMZERO_KEY="$(cat domzero_pubkey)"

remote_bash "root@$XENSERVER" << EOF
set -eux
DEVSTACK=\$(xe vm-list name-label=$DEVSTACK_NAME --minimal)

SLAVE=\$(xe vm-list name-label=slave --minimal)

SLAVE_VBD=\$(xe vbd-list vm-uuid=\$SLAVE userdevice=1 --minimal)

xe vbd-unplug uuid=\$SLAVE_VBD

xe vbd-destroy uuid=\$SLAVE_VBD

echo "$DOMZERO_KEY" >> .ssh/authorized_keys
EOF
