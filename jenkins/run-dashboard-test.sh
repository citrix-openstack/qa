#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

usr_mail="${EmailAddress-$TEST_MAIL_ACCOUNT}"
img_id="${ImageId-3}"
net_addr="${NetworkAddress-10.0.0.}"
p_net="${PublicNetwork-$TEST_XENSERVER_P_NET}"
master_vpx_host="${Server-$TEST_XENSERVER}"
net_mode="${NetworkingMode-flat}" # can be flat, flatdhcp, vlan, flatdhcp-ha
floating_ip_range="${FloatingIPRange-$FLOATING_IP_RANGE}"
dashboard_host=
dashboard_addr=
tunnel_port=
compute_host=
if [ "$#" -eq 0 ]
then
  master=$(remote_execute "root@$master_vpx_host" \
                          "$thisdir/utils/get_master_address.sh")
  establish_tunnel "$master" 8080 "$master_vpx_host" tunnel_port
  master_url="http://localhost:$tunnel_port"
  
  dashboard_host=$(get_os_svc_property "$master_url" \
                                       "openstack-dashboard" \
                                       "host_fqdn")
  dashboard_addr=$(get_os_svc_property "$master_url" \
                                       "openstack-dashboard" \
                                       "hostnetwork_ip")
  compute_host=$(get_os_svc_property "$master_url" \
                                     "openstack-nova-compute" \
                                     "host_fqdn")
elif [ "$#" -eq 4 ]
then
  dashboard_host="$1"
  dashboard_addr="$2"
  tunnel_port="$3"
  compute_host="$4"
fi

vdis_num_pre=$(remote_execute "root@$compute_host" \
                              "$thisdir/utils/check-for-vdis.sh")

echo "Contacting openstack-dashboard on $dashboard_host:$dashboard_addr."

dashboard_port=$(($tunnel_port+1))
establish_tunnel "$dashboard_addr" 9999 "$dashboard_host" dashboard_port
dashboard_url="http://localhost:$dashboard_port"

# Test OpenStack Dashboard
selenium_port=$(($dashboard_port+1))
start_selenium_rc $selenium_port

set +e
python "$thisdir/os-dashboard/test_dashboard.py" "$dashboard_url" \
                                                 "$selenium_port" \
                                                 "$thisdir" \
                                                 "$usr_mail" \
                                                 "$img_id" \
                                                 "$net_addr" \
                                                 "$net_mode"
code=$?
if [ "$code" -ne 0 ]
then
  parse_result "$code"
  exit $code
fi
set -e

remote_execute "root@$compute_host" \
       "$thisdir/os-dashboard/check-instance-bridge.sh" \""$p_net"\"

set +e
python "$thisdir/os-dashboard/test_dashboard_post.py" "$dashboard_url" \
                                                      "$selenium_port" \
                                                      "$thisdir"

code=$(parse_result "$?")
[ $code -ne 0 ] && exit $code
set -e

vdis_num_post=$(remote_execute "root@$compute_host" \
                               "$thisdir/utils/check-for-vdis.sh")
vdis_diff=$(($vdis_num_post-$vdis_num_pre))
if [ $vdis_diff -gt 0 ]
then
    echo "There are VDIs that have not been cleaned properly, exit with error!"
    exit 1 
fi
