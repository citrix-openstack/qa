#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

cd $stackdir

cd devstack
git checkout xenservermodif

cd $stackdir/devstack
defaultlocalrc="http://gold.eng.hq.xensource.com/localrc"
lrcurl="${localrcURL-$defaultlocalrc}"
if [ ! -f localrc ]
then
    wget $lrcurl
fi

cd tools/xen
./build_xva.sh SCAPTPROXY=$scaptproxy

