#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

autosite="${AUTOSITE-false}"
if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

remote_xe_min()
{
  local host="$1"
  local cmd="$2"
  shift 2
  ssh root@$host "xe $cmd --minimal $@"
}

run_install()
{
  local server=$1
  local num_master=$2
  local kargs=$3
  local m_ram=$4
  local num_slaves=$5
  local s_ram=$6
  local wait=$7
  local man_ip=$8 
  m_net=$(remote_xe_min $server network-list name-label=$m_net_label params=bridge)
  pif_uuid=$(remote_xe_min $server network-list bridge=$m_net params=PIF-uuids)
  m_nic=$(remote_xe_min $server pif-list uuid=$pif_uuid params=device)
  p_net=$(remote_xe_min $server network-list name-label=$p_net_label params=bridge)
  install "$server" "$m_nic" "$num_master" "$kargs" "$m_ram" \
          "$num_slaves" "$s_ram" "" "$man_ip" "$m_net" "$p_net"

}

password="${Password-$XS_ROOT_PASSWORD}"
ballo="${Ballooning-false}"
devel="${Devel-false}"

# It is up to the user ensure that the bridges corresponding to the
# management network exists on each host and is mapped to the same
# physical/VLAN network.
# The public and guest networks instead will be VLANs on the NICs
# specified by the user. If the user specifies a VLAN ID equal to 0,
# then the no VLAN will be configured

g_net_nic="${GuestNetworkNic-eth1}"
m_net_nic="${ManagementNetworkNic-eth1}"
p_net_nic="${PublicNetworkNic-eth1}"
# Note: the VLAN for guest networking will not be used in tests with
# the VLAN network manager
g_net_vlan="${GuestNetworkVLAN-237}"
m_net_vlan="${ManagementNetworkVLAN-4093}"
p_net_vlan="${PublicNetworkVLAN-238}"

m_ram="${Master_memory-700}"
s_ram="${Slave_memory-500}"
kargs="${MasterBootOptions-$MASTER_BOOT_OPTIONS}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"


net_mode="${NetworkingMode-flat}"    # can be flat, flatdhcp, vlan, flatdhcp-ha
floating_ip_range="${FloatingIPRange-$FLOATING_IP_RANGE}"
dns_suffix="${DnsSuffix-openstack.com}"

# This script assumes we are running the test on 4 servers

server1="${Server1-$TEST_XENSERVER_NETSUITE_1}"
server2="${Server2-$TEST_XENSERVER_NETSUITE_2}"
server3="${Server3-$TEST_XENSERVER_NETSUITE_3}"
server4="${Server4-$TEST_XENSERVER_NETSUITE_4}"

m_net_label="OS-Man#"$m_net_vlan
p_net_label="OS-Pub#"$p_net_vlan
g_net_label="OS-Gst#"$g_net_vlan
servers=( $server1 $server2 $server3 $server4 )
pids=
for server in ${servers[@]}
do
  # Avoid duplication in bridge names
  ( 
    echo "Building management network on "$server" on VLAN "$m_net_vlan
    $thisdir/guest_networking/build_networks.sh $server $m_net_nic $m_net_vlan $m_net_label
    echo "Building public services network on "$server" on VLAN "$p_net_vlan
    $thisdir/guest_networking/build_networks.sh $server $p_net_nic $p_net_vlan $p_net_label
    echo "Building guest instance network on "$server" on VLAN "$g_net_vlan
    $thisdir/guest_networking/build_networks.sh $server $g_net_nic $g_net_vlan $g_net_label
  ) &
  pids="$pids $!"
done
wait_for "$pids"

echo "Network setup complete. Installing VPXs"

master_vpx_host=

pids=

run_install "$server1" 1 "$kargs" "$m_ram" 3 "$s_ram" "" "192.168.1.2"
wait_for "$pids" # Wait for the first one to succeed, to allow the local
                 # cache to populate.  There's no point trying to download
                 # the VPX in parallel across all machines at once.

run_install "$server2" 0 "" "" 3 "$s_ram" "1" "192.168.1.3"
run_install "$server3" 0 "" "" 3 "$s_ram" "1" "192.168.1.4"
run_install "$server4" 0 "" "" 2 "$s_ram" "1" "192.168.1.5"

wait_for "$pids"
master_vpx_host="$server1"

echo "VPXs installed. Waiting for slaves to report to the master"

# TEST OPENSTACK CLOUD DEPLOYMENT
master=$(remote_execute "root@$master_vpx_host" \
                        "$thisdir/utils/get_master_address.sh")
port=
establish_tunnel "$master" 8080 "$master_vpx_host" port
master_url="http://localhost:$port"

# Check that we've had 11 + 1 nodes registered.  This is what install_vpxs.sh
# should have installed. The +1 comes from the master, that also registers 
# with itself.
"$thisdir/utils/check-nodes" "$master_url" 12

# Set global configs before deplyoing any role. Changing flags values  
# should happen here; argv[2] is a comma-separated string of keyvalue
# pairs. If values have spaces, quote them with '
"$thisdir/utils/set_globals" "$master_url" \
                             "DASHBOARD_SMTP_SVR=$smtp_svr,\
                              GUEST_NETWORK_BRIDGE=$g_net_label"

# Must retrieve VPXs for each host
nodes=$("$thisdir/utils/get-all-nodes" "$master_url")
node_array=( $nodes )
. $thisdir/guest_networking/ROLEMAPPINGS

rolemappings_file=$thisdir/guest_networking/vpx_role_mappings
echo "" > $rolemappings_file
let srv_counter=1
for server in ${servers[@]}
do
  let mac_counter=1  
  for node in ${node_array[@]}
  do
    mac=$("$thisdir/utils/get-mac-from-node" "$node")
    result=$(remote_xe_min $server vif-list params=vm-uuid MAC=$mac)
    if [ "$result" != "" ]; then
      varname=worker`echo $srv_counter$mac_counter`_roles[@]
      roles=${!varname}
      echo $node $server ${roles[@]} >> $rolemappings_file
      echo $node $server ${roles[@]}
      #remove element from array
      node_array=( "${node_array[@]#$node}" )
      mac_counter=$(( mac_counter + 1 ))
    fi 
  done
  srv_counter=$(( srv_counter + 1 ))
done

add_on_exit "rm -f $rolemappings_file"

# Do an automated cloud setup - and check the cloud is up and running

set +e
echo "Setting up cloud deployment..."
python "$thisdir/guest_networking/setup_cloud.py" "$master_url" \
                                                  "$password" \
                                                  "$rolemappings_file" \
		                                          "$net_mode" \
	                                          	  "$m_net_label" \
												  "$p_net_label" \
												  "$g_net_label" \
	                                              "$floating_ip_range" \
	                                              "$dns_suffix"

code=$(parse_result "$?")
[ "$code" != "0" ] && exit $code

selenium_port=$(($port+1))
start_selenium_rc "$selenium_port"
# Do the geppetto test, but only for a few stuff
# Skip the test which have already been performed
skip_list="00,01,02,03,04,05,06,07,08,09,12,14"
python "$thisdir/geppetto/test_master.py" "$master_url" \
                                          "$selenium_port" \
                                          "$thisdir" \
                                          "$password" \
                                          "$GUEST_NETWORK" "8" \
                                          "$net_mode" \
                                          "$g_net_label" \
                                          "$p_net_label" \
                                          "$floating_ip_range" \
                                          "$skip_list"
code=$(parse_result "$?")
exit $code

