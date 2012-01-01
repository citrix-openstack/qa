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
nova_api_addr=
nova_api_port=
tunnel_port=

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
  service_host=$master_vpx_host
  nova_api_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-nova-api" \
                                    "hostnetwork_ip")
elif [ "$#" -eq 3 ]
then
  service_host="$1"
  nova_api_addr="$2"
  tunnel_port="$3"
fi

echo "Contacting nova-api on $service_host:$nova_api_addr."
nova_api_port=$(($tunnel_port+1))
establish_tunnel "$nova_api_addr" 8774 "$service_host" nova_api_port
nova_api_url="http://localhost:$nova_api_port"

set +e
python "$thisdir/fast-cloning/test_fast_cloning.py" "$nova_api_url" "$no_of_instances" "$img_id" "$flavor_id" 
code=$?
exit $code
