#!/bin/bash

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common.sh"

label="$1"
url="$2"
dev="$4"
number_of_clients="$4"

cd "$thisdir"
fetch_vpx_scripts "$url"

master_vpx=$(get_vm_uuid_by_other_config "vpx-test-master=true")
m_net=$(get_bridge_by_vm_and_device "$master_vpx" 1)
p_net=$(get_bridge_by_vm_and_device "$master_vpx" 2)
m_ram=$(xe_min vm-param-get param-name=memory-static-max uuid="$master_vpx")
let "m_ram = $m_ram >> 20"    # express m_ram in MiB

# TODO - remove hardcoding
ballooning_flag=
m_ram=500
s_ram=500
disk_mb=500

for i in $(seq 1 $number_of_clients)
do
    if [ "$i" = "$number_of_clients" ]
    then
        wait="1"
    else
        wait=""
    fi
   
    install_vpx "-c$label" \
                "$wait" "$m_net" "$p_net" \
                "geppetto_master=false" "slave" \
                "100" "$s_ram" "$ballooning_flag"
    sleep 60    # attempting to avoid DDNS registration failures
done
