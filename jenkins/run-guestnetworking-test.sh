#!/bin/bash

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
net_mode="${NetworkingMode-flat}"    # can be flat, flatdhcp, vlan, flatdhcp-ha
spawn_timeout=${SpawnTimeout-600} #Plenty of time...
boot_timeout=${BootTimeout-75}

## THIS IS A HACK, BUT IT'LL DO FOR THE TIME BEING ##
if [ "$net_mode" != "flat" ]
then
    server="${Server-$TEST_XENSERVER_2}"
else
	server="${Server-$TEST_XENSERVER}"
fi
server_mgmt_ip_1=192.168.1.2
server_mgmt_array=( $server_mgmt_ip_1 )

# TEST GUEST INSTANCE NETWORKING IN OPENSTACK CLOUD
# Find master VPX address, set tunnel to geppetto service
master=$(remote_execute "root@$server" \
                        "$thisdir/utils/get_master_address.sh")
port=
establish_tunnel "$master" 8080 "$server" port
master_url="http://localhost:$port"
keystone_worker=$(get_os_svc_property $master_url \
								       "openstack-keystone-admin" \
								       "hostnetwork_ip")
network_worker=$(get_os_svc_property $master_url \
								       "openstack-nova-network" \
								       "hostnetwork_ip")

echo "KEYSTONE WORKER:" $keystone_worker

set +e
# NOT VERY EXCITED BY THIS, BUT RUN TESTS REMOTELY (ON THE NETWORK WORKER)
#Copy files to XS host
tmpdir=$(ssh "root@$server" mktemp -d)
scp $thisdir/guest_networking/* root@$server:/$tmpdir
add_on_exit "ssh root@$server rm -rf $tmpdir"

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
remote_execute "root@$server" "$thisdir/guest_networking/test_runner.sh" "$test_args"

code=$(parse_result "$?")
exit $code
