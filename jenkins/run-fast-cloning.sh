#!/bin/bash

set -eux
thisdir=$(dirname "$0")

. "$thisdir/common.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

master_vpx_host="${Server-$TEST_XENSERVER}"
no_of_instances="${NumberOfInstances-5}"
img_id="${ImageId-}"
flavor_id="${FlavorId-1}"

if [ $no_of_instances -lt 2 ]
then
  echo "Value of the input parameter, NumberofInstances should be greater than 1"
  exit 1
fi

if [ "$#" -eq 0 ]
then
  master=$(remote_execute "root@$master_vpx_host" \
                          "$thisdir/utils/get_master_address.sh")
  establish_tunnel "$master" 8080 "$master_vpx_host" tunnel_port
  master_url="http://localhost:$tunnel_port"
  keystone_auth_host=$master_vpx_host
  keystone_auth_addr=$(get_os_svc_property "$master_url" \
                                           "openstack-keystone-auth" \
                                           "hostnetwork_ip")
  nova_api_host=$master_vpx_host
  nova_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-nova-api" \
                                    "hostnetwork_ip")
elif [ "$#" -eq 5 ]
then
  keystone_auth_host="$1"
  keystone_auth_addr="$2"
  nova_api_host="$3"
  nova_api_addr="$4"
  tunnel_port="$5"
fi

echo "Contacting keystone on $keystone_auth_host:$keystone_auth_addr."
keystone_auth_port=$(($tunnel_port+1))
establish_tunnel "$keystone_auth_addr" 5000 "$keystone_auth_host" \
                 keystone_auth_port
keystone_auth_url="http://localhost:$keystone_auth_port"

echo "Contacting nova-api on $nova_api_host:$nova_api_addr."
nova_api_port=$(($tunnel_port+2))
establish_tunnel "$nova_api_addr" 8774 "$nova_api_host" nova_api_port
nova_api_url="http://localhost:$nova_api_port"

set +e
python "$thisdir/fast-cloning/test_fast_cloning.py" "$keystone_auth_url" \
       "$nova_api_url" "$no_of_instances" "$img_id" "$flavor_id"
code=$?
exit $code
