#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

#
# Install first host
#

export Server=$Server1
. "$thisdir/run-devstack-xen.sh"

#
# Install second host (compute slave)
#
. "$thisdir/run-devstack-multi.sh"

#
# Run tests
#
export Server=$Server1
. "$thisdir/run-devstack-tests.sh"
