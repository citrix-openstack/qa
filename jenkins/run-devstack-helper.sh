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
wget -N $lrcurl

#
# NOTE: this needs to run as root
#
cd tools/xen
SCAPTPROXY=$scaptproxy ./build_xva.sh

