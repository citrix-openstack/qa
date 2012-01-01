#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common-esx41.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

usr_mail="${EmailAddress-$TEST_MAIL_ACCOUNT}"
#### I have no idea where ImageId or InstanceId is defined!
img_id="${ImageId-3}"
ins_id="${InstanceId-1}"
net_addr="${NetworkAddress-10.0.0.2}"
# This gnetw doesn't seem to matter.
gnetw="${GuestNetwork-$TEST_XENSERVER_P_NET}"
master_vpx_host="${Server-$TEST_ESX_SINGLE_TEST_SERVER}"
dashboard_host=
dashboard_addr=
tunnel_port=
compute_host=
if [ "$#" -eq 0 ]
then
  # We know that on ESX, for this test case only, the host network
  # IP of the master VPX will always be 192.168.128.2.
  # So just hard code that.
  master="192.168.128.2"
  establish_tunnel "$master" 8080 "$master_vpx_host" tunnel_port
  master_url="http://localhost:$tunnel_port"
  
  dashboard_host="$master_vpx_host"
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

echo "Contacting openstack-dashboard on $dashboard_host:$dashboard_addr."

dashboard_port=$(($tunnel_port+1))
establish_tunnel "$dashboard_addr" 9999 "$dashboard_host" dashboard_port
dashboard_url="http://localhost:$dashboard_port"

# Test OpenStack Dashboard
selenium_port=$(($dashboard_port+1))
start_selenium_rc $selenium_port

# Now test_dashboard.py seems to ignore gnetw.. and net_addr is
# hard coded in it.. so this probably will work rightaway.
set +e
python "$thisdir/os-dashboard/test_dashboard.py" "$dashboard_url" \
                                                 "$selenium_port" \
                                                 "$thisdir" \
                                                 "$usr_mail" \
                                                 "$img_id" \
                                                 "$ins_id" \
                                                 "$net_addr" \
                                                 "$gnetw"
                                   
# We can't be calling this - it seems to be XS-specific.              
#set -e
#remote_execute "root@$compute_host" \
#       "$thisdir/os-dashboard/check-instance-bridge.sh" "$ins_id" \
#       													"$gnetw"

#set +e
python "$thisdir/os-dashboard/test_dashboard_post.py" "$dashboard_url" \
                                                      "$selenium_port" \
                                                      "$thisdir" \
                                                      "$ins_id"

code=$(parse_result "$?")
exit $code
