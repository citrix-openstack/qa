#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"
. "$thisdir/common-ssh.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

master_vpx_host="${Server-$TEST_XENSERVER}"
glance_host=
glance_addr=
tunnel_port=
if [ "$#" -eq 0 ]
then
  master=$(remote_execute "root@$master_vpx_host" \
                          "$thisdir/utils/get_master_address.sh")
  establish_tunnel "$master" 8080 "$master_vpx_host" tunnel_port
  master_url="http://localhost:$tunnel_port"
  
  glance_host=$master_vpx_host
  glance_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-glance-api" \
                                    "hostnetwork_ip")
elif [ "$#" -eq 3 ]
then
  glance_host="$1"
  glance_addr="$2"
  tunnel_port="$3"
fi

echo "Copying Glance client code..."
ssh_port=
establish_tunnel "$glance_addr" 22 "$glance_host" ssh_port
keyfile=$(mktemp -u)
gen_key
upload_key_to_vpx localhost "citrix" $keyfile $ssh_port
scp_no_hosts -r -P "$ssh_port" \
    "localhost:/usr/lib/python2.6/site-packages/glance" "$WORKSPACE"
echo "Copying Glance client code done."

echo "Contacting glance-api on $glance_host:$glance_addr."

glance_port=$(($tunnel_port+1))
establish_tunnel "$glance_addr" 9292 "$glance_host" glance_port
glance_url="http://localhost:$glance_port"

export PYTHONPATH="$WORKSPACE"
"$thisdir/glance-stream/glance-stream-test" "$glance_url"
