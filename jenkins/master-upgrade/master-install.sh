#!/bin/bash

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common.sh"

label="$1"
url="$2"
dev="$3"
vdi="$4"

cd "$thisdir"
fetch_vpx_pieces "$url" "$dev"

master_vpx=$(get_any_vm_uuid_by_other_config "vpx-test-master=false")
m_net=$(get_bridge_by_vm_and_device "$master_vpx" 1)
p_net=$(get_bridge_by_vm_and_device "$master_vpx" 2)
m_ram=$(xe_min vm-param-get param-name=memory-static-max uuid="$master_vpx")
let "m_ram = $m_ram >> 20"    # express m_ram in MiB
kargs=$(xe_min vm-param-get param-name=PV-args uuid="$master_vpx")

# TODO: Replace this with actual value
disk_mb=500

sh -x install-os-vpx.sh -i -w \
                        -l "$label" \
                        -m "$m_net" \
                        -p "$p_net" \
                        -k "$kargs" \
                        -r "$m_ram" \
                        -d "$disk_mb" \
                        -a "$vdi" \
                        -o "vpx-test-master=true vpx-test=true"

master_uuid=$(get_vm_uuid_by_other_config "vpx-test-master=true")
vif_device=1   # This is the VIF for management traffic
wait_for_vif_up "$master_uuid" "$vif_device" "$m_net"
