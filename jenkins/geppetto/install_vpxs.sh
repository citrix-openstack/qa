#!/bin/sh

#
# Create two VPXs on this host, one master, one slave, and join them up with
# a local management network.
#

set -eux

thisdir=$(dirname "$0")

. "$thisdir/common.sh"

url="$1"
dev="$2"
m_net="$3"
p_net="$4"
devel="$5"
ballo="$6"
m_ram="$7"
s_ram="$8"
number_of_clients="$9"
install_master="${10}"
kargs="${11}"

cd "$thisdir"

fetch_vpx_pieces "$url" "$devel"
clean_host
m_net=$(introduce_xapi_to_management_network "$dev" "$m_net" 192.168.1.2 255.255.255.0)

install_xenserver_openstack_supp_pack
"$ballo" == "true" && ballooning_flag="-b" || ballooning_flag=""

if [ "$install_master" == "true" ]
then
    install_vpx -i "" "$m_net" "$p_net" \
            "$kargs" "master" \
            "500" "$m_ram" "$ballooning_flag"
fi

template_label=$(find_template_name_by_other_config "os-vpx=true")

for i in $(seq 1 $number_of_clients)
do
    if [ "$i" = "$number_of_clients" ]
    then
        wait=1
    else
        wait=
    fi
    install_vpx "-c$template_label" "$wait" "$m_net" "$p_net" \
                "geppetto_master=false" "slave" "100" "$s_ram" \
                "$ballooning_flag"
done
