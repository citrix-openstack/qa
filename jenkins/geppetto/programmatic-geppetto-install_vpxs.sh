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
kargs="geppetto_master=true geppetto_ip=10.10.5.5 geppetto_mask=255.255.255.0 geppetto_gw=10.10.5.1 geppetto_first_ip=10.10.5.100 geppetto_last_ip=10.10.5.190 geppetto_hostname=themaster geppetto_dns_suffix=openstack.com"

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
    sh -x install-os-vpx.sh -m xenbr1 -p xenbr0 -k geppetto_master=false \
                -r 500 -d 100 -b -o 'vpx-test-slave=true vpx-test=true'
done
