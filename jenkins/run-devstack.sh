#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

sudo su -

server=brontitall.eng.hq.xensource.com
stackdir="/tmp/stack"

mkdir -p $stackdir

cd $stackdir

if [ ! -d $stackdir/devstack ]
then
    git clone git@github.com:renuka-apte/devstack.git
fi

cd devstack
git checkout xenservermodif

cd $stackdir/devstack
if [ ! -f localrc ]
then
    wget http://gold.eng.hq.xensource.com/localrc
fi

cd tools/xen
./build_xva.sh

mv stage /tmp/
cd ../../../
scp -r devstack root@$server:~/
mv /tmp/stage $stackdir/devstack/tools/xen

remote_execute "root@$server" \
                   "$thisdir/devstack/on-host.sh"
