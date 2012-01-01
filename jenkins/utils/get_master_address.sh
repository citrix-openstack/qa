#!/bin/sh

#
# Get the IP address of the master VPX (other-config:vpx-test-master=true).
#

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

master_uuid=$(get_vm_uuid_by_other_config "vpx-test-master=true")
echo "Found VM uuid for master: $master_uuid" >&2

# We want the address of Host Internal Management Network
# (aka xapi0). On the VPX this corresponds to VIF 0   
master_addr=$(get_vm_address "$master_uuid" 0)
echo "Found IP address for master: $master_addr" >&2

echo "$master_addr"
