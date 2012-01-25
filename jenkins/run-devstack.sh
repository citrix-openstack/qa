#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

#enter_jenkins_test

server=brontitall.eng.hq.xensource.com
stackdir="/tmp/stack"

mkdir $stackdir

add_on_exit "rm -rf ${stackdir}"

cd $stackdir

git clone git@github.com:renuka-apte/devstack.git
cd devstack
git checkout xenservermodif

cd $stackdir/devstack
wget http://gold.eng.hq.xensource.com/localrc

cd tools/xen
./build_xva.sh

rm -rf stage
cd ../../../
scp -r devstack root@$server:~/

remote_execute "root@$server" \
                   "$thisdir/devstack/on-host.sh"
