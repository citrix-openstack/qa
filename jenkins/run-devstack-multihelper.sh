#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

#
# NOTE: this needs to run as root
#
cd $stackdir/devstack/tools/xen
SCAPTPROXY=$scaptproxy HEAD_PUB_IP="dhcp" HEAD_MGT_IP=192.168.1.1 COMPUTE_PUB_IP="dhcp" COMPUTE_MGT_IP=192.168.1.2 FLOATING_RANGE=10.0.0.2/30 ./build_domU_multi.sh
