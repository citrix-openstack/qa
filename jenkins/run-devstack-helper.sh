#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

#
# NOTE: this needs to run as root
#
cd $stackdir/devstack/tools/xen
SCAPTPROXY=$scaptproxy ./build_xva.sh

