#!/bin/bash
# This script launches guest instance networking tests on a multihost environment

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"
. "$thisdir/common-vpx.sh"

autosite="${AUTOSITE-false}"
if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

xenapi_pw="${Password-$XS_ROOT_PASSWORD}"
xenapi_url="${XenAPIUrl-"http://169.254.0.1"}"
gnetw_br="${GuestNetworkBridge-xapi0}"
br_iface="${BridgeInterface-eth3}"
net_mode="${NetworkingMode-flat}"    # Can be flat, flatdhcp, vlan (use -ha suffix for high availability mode)
spawn_timeout=${SpawnTimeout-600}    # Allow plenty of time...
boot_timeout=${BootTimeout-50}
host_suffix="${HostSuffix-eng.hq.xensource.com}"

#We need the Server running the Master VPX
server="${MasterServer-$TEST_XENSERVER_NETSUITE_1}"
server_mgmt_ip_1=${MasterServerManagementIP-192.168.1.2}
server_mgmt_array=( $server_mgmt_ip_1 )

# TEST GUEST INSTANCE NETWORKING IN OPENSTACK CLOUD
# Find master VPX address, set tunnel to geppetto service
master=$(remote_execute "root@$server" \
                        "$thisdir/utils/get_master_address.sh")
port=
establish_tunnel "$master" 8080 "$server" port
master_url="http://localhost:$port"
sleep 2
keystone_worker=$(get_os_svc_property $master_url \
								       "openstack-keystone-admin" \
								       "management_ip")
								       
# MULTI-HOST implies multiple network workers.
# Anyone is fine for us, so fetch the first!
network_worker=$(get_os_svc_property $master_url \
								       "openstack-nova-network" \
								       "management_ip")

# FIND HOST FOR THE NETWORK WORKER
network_worker_server=$(get_os_svc_property $master_url \
								       "openstack-nova-network" \
								       "host_fqdn")
network_worker_server="$network_worker_server"."$host_suffix"
set +e
# NOT VERY EXCITED BY THIS, BUT RUN TESTS REMOTELY (ON THE NETWORK WORKER)
# Copy files to XS host
tmpdir=$(ssh "root@$network_worker_server" mktemp -d)
scp $thisdir/guest_networking/* root@$network_worker_server:/$tmpdir
add_on_exit "ssh root@$network_worker_server rm -rf $tmpdir"

test_module=test_guest_networking.py
test_args=$( echo "$tmpdir" \
				  "$network_worker" \
				  "$test_module" \
                  "$keystone_worker" \
                  "$net_mode" \
                  "$gnetw_br" \
                  "$br_iface" \
                  "$xenapi_url" \
                  "$xenapi_pw" \
                  "$spawn_timeout" \
                  "$boot_timeout")
remote_execute "root@$network_worker_server" "$thisdir/guest_networking/test_runner.sh" "$test_args"

code=$(parse_result "$?")
exit $code
