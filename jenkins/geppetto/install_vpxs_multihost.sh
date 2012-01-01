#!/bin/sh

#
# Create m master VPXs and n slave VPXs on this host, where m and n are given
# on the command line.  Connect them to the specified networks.
#

set -eux

thisdir=$(dirname "$0")

. "$thisdir/common.sh"

url="$1"
dev="$2"
m_net="$3"
p_net="$4"
devel="$5"
masters="$6"
kargs="$7"
m_ram="$8"
slaves="$9"
s_ram="${10}"
wait_at_end="${11}"
static_management_ip="${12}"

cd "$thisdir"

fetch_vpx_pieces "$url" "$devel"
clean_host
install_xenserver_openstack_supp_pack

m_net=$(introduce_xapi_to_management_network "$dev" "$m_net" "$static_management_ip" \
        255.255.255.0)

mode="-i"
for i in $(seq 1 "$masters")
do
    if [ "$wait_at_end" ] && [ "$i" = "$masters" ] && [ "$slaves" = 0 ]
    then
        wait=1
    else
        wait=
    fi
    install_vpx "$mode" "$wait" "$m_net" "$p_net" \
                "$kargs" \
                "master" "500" "$m_ram" ""
    template_label=$(find_template_name_by_other_config "os-vpx=true")
    mode="-c$template_label"
done
for i in $(seq 1 "$slaves")
do
    if [ "$wait_at_end" ] && [ "$i" = "$slaves" ]
    then
        wait=1
    else
        wait=
    fi
    install_vpx "$mode" "$wait" "$m_net" "$p_net" "geppetto_master=false" \
                "slave" "100" "$s_ram" ""
    template_label=$(find_template_name_by_other_config "os-vpx=true")
    mode="-c$template_label"
done
