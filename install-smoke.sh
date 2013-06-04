#!/bin/bash

# sudo apt-get update
# sudo apt-get install -qy rake libxslt1-dev git

# TODO: kytoon needs some fixes
# sudo gem install kytoon
# touch ~/.kytoon.conf

# ssh-keygen -q -C "devbox" -N "" -f ~/.ssh/id_rsa_devbox
# ssh-copy-id -i ~/.ssh/id_rsa_devbox.pub root@192.168.32.125
# eval $(ssh-agent)
# ssh-add ~/.ssh/id_rsa_devbox

# git clone git://github.com/dprince/firestack.git firestack
# cd firestack
# ./example_xen.bash 192.168.32.125 somepass

set -eux

# TODO
XENSERVER=192.168.32.114
SMOKE_ROOT_URL="http://copper.eng.hq.xensource.com/smoke-images"


function xenserver()
{
ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    "root@$XENSERVER" bash -s --
}

if ! echo "true" | xenserver; then
    ssh-copy-id -i ~/.ssh/id_rsa.pub root@$XENSERVER
fi

if ! echo "[ -h /images ]" | xenserver; then
    SR=$(echo "xe sr-list type=ext --minimal" | xenserver)
    echo "mkdir -p /var/run/sr-mount/$SR/smoke-images" | xenserver
    echo "[ -h /images ] || ln -s /var/run/sr-mount/$SR/smoke-images /images" | xenserver
fi

for fname in fedora18-buildbox.xva fedora18-db.xva squeeze-agent-0.0.1.31.ova; do
    echo -n "$fname"
    xenserver << EOF
set -eu
[ -e /images/$fname ] || \\
wget -qO /images/$fname $SMOKE_ROOT_URL/$fname
EOF
    echo " done!"
done

NET=$(echo "xe network-list name-label=smokeinternal --minimal" | xenserver)
if [ -z "$NET" ]; then
    echo "xe network-create name-label=smokeinternal" | xenserver
fi

BRIDGE=$(echo "xe network-list name-label=smokeinternal params=bridge --minimal" | xenserver)

if ! echo "[ -e ~/.ssh/id_rsa ]" | xenserver; then
    echo "ssh-keygen -q -C root@hypervisor -N '' -f ~/.ssh/id_rsa" | xenserver
fi

# Install git in Dom0
if [ -z $(echo "which git" | xenserver) ]; then
    xenserver << EOF
set -eux
wget http://dl.fedoraproject.org/pub/epel/5/i386/epel-release-5-4.noarch.rpm
rpm -Uvh epel-release-5-4.noarch.rpm
yum -y install git
rpm -ev epel-release
rm -f epel-release-5-4.noarch.rpm
EOF
fi
