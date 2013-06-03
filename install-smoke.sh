#!/bin/bash

# sudo apt-get update
# sudo apt-get install -qy rake libxslt1-dev git

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

XENSERVER=192.168.32.125

function xenserver()
{
ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    "root@$XENSERVER" bash -s --
}

SR=$(echo "xe sr-list type=ext --minimal" | xenserver)
echo "mkdir -p /var/run/sr-mount/$SR/smoke-images" | xenserver
echo "[ -h /images ] || ln -s /var/run/sr-mount/$SR/smoke-images /images" | xenserver

for fname in fedora18-buildbox.xva fedora18-db.xva squeeze-agent-0.0.1.31.ova; do
    xenserver << EOF
set -exu
[ -e /images/$fname ] || \\
wget -qO /images/$fname http://copper.eng.hq.xensource.com/smoke-images/$fname
EOF
done
