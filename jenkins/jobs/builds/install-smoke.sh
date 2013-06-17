#!/bin/bash

# sudo apt-get update

set -eux

XENSERVER=$(cat ~/.vhip)
SMOKE_ROOT_URL="http://copper.eng.hq.xensource.com/smoke-images"

function setup_ssh() {
    eval $(ssh-agent)
    ssh-add ~/.ssh/id_rsa_devbox
}

function xenserver() {
ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    "root@$XENSERVER" bash -s --
}

function prepare_xenserver() {
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
}

function setup_kytoon() {
    sudo apt-get -q update
    sudo apt-get install -qy rake libxslt1-dev git

    sudo gem install jeweler thor builder uuidtools --no-ri --no-rdoc

    rm -rf kytoon
    git clone git://github.com/matelakat/kytoon.git -b labfixes kytoon
    (
        cd kytoon
        rake build
        sudo gem install pkg/*.gem --no-ri --no-rdoc
    )

    touch ~/.kytoon.conf
}

function get_smokeinternal_bridge_name() {
    echo "xe network-list name-label=smokeinternal params=bridge --minimal" | xenserver
}

function prepare_firestack() {
    local bridgename

    bridgename="$1"

    rm -rf firestack
    git clone git://github.com/dprince/firestack.git firestack
    (
        cd firestack
        sed -i config/server_group_xen.json -e "s/xenbr1/$bridgename/g"
    )
}

function start_firestack() {
    cd firestack
    ./example_xen.bash "$XENSERVER" somepass
}

setup_ssh
prepare_xenserver
setup_kytoon
prepare_firestack "$(get_smokeinternal_bridge_name)"
start_firestack
