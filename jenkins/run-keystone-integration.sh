#!/bin/bash

set -eux
thisdir=$(dirname "$0")

. "$thisdir/common.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

master_vpx_host="${Server-$TEST_XENSERVER}"
glance_host=
glance_addr=
nova_api_addr=
keystone_api_addr=
swift_api_addr=
tunnel_novaapi_port=
tunnel_port=

if [ "$#" -eq 0 ]
then
  master=$(remote_execute "root@$master_vpx_host" \
                          "$thisdir/utils/get_master_address.sh")
  establish_tunnel "$master" 8080 "$master_vpx_host" tunnel_port
  master_url="http://localhost:$tunnel_port"
    
  service_host=$master_vpx_host
  
  nova_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-nova-api" \
                                    "hostnetwork_ip")
  keystone_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-keystone-auth" \
                                    "hostnetwork_ip")
  glance_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-glance-api" \
                                    "hostnetwork_ip")
  swift_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-swift-proxy" \
                                    "hostnetwork_ip")
elif [ "$#" -eq 3 ]
then
  
  service_host="$1"
  nova_api_addr="$2"
  nova_tunnel_port="$3"
  keystone_api_addr="$4"
  keystone_tunnel_port="$5"
  glance_api_addr="$4"
  glance_tunnel_port="$5"
  
fi

echo "Contacting nova-api on $service_host:$nova_api_addr."
echo "Contacting keystone-api on $service_host:$keystone_api_addr."
echo "Contacting glance-api on $service_host:$glance_api_addr."

nova_api_port=$(($tunnel_port+1))
keystone_api_port=$(($tunnel_port+2))
glance_api_port=$(($tunnel_port+3))
swift_api_port=$(($tunnel_port+4))

establish_tunnel "$nova_api_addr" 8774 "$service_host" nova_api_port
establish_tunnel "$keystone_api_addr" 35357 "$service_host" keystone_api_port
establish_tunnel "$glance_api_addr" 9292 "$service_host" glance_api_port
establish_tunnel "$swift_api_addr" 443 "$service_host" swift_api_port

nova_api_url="http://localhost:$nova_api_port"
keystone_api_url="http://localhost:$keystone_api_port"
glance_api_url="http://localhost:$glance_api_port"
swift_api_url="https://localhost:$swift_api_port"

set +e
python "$thisdir/keystone-integration/test_keystone_integration.py" "$nova_api_url" "$keystone_api_url" "$glance_api_url" "$swift_api_url"
code=$?
set -e
if [ $code -ne 0 ]
then
  python "$thisdir/keystone-integration/test_remove_setup.py" "$nova_api_url" "$keystone_api_url" "$glance_api_url" "$swift_api_url"
  exit $code
fi

exit $code
