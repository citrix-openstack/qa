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

password="${Password-$XS_ROOT_PASSWORD}"
ballo="${Ballooning-false}"
devel="${Devel-false}"
skipd="${ShortRun-false}"
gnetw="${GuestNetwork-$GUEST_NETWORK}"
m_net="${ManagementNetwork-$TEST_XENSERVER_M_NET}"
p_net="${PublicNetwork-$TEST_XENSERVER_P_NET}"
m_ram="${Master_memory-700}"
s_ram="${Slave_memory-500}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
usr_mail="${EmailAddress-${TEST_MAIL_ACCOUNT-}}"

server="${Server-$TEST_XENSERVER}"
if [ "$#" -eq 1 ]
then
  server="$1"
fi

# Networks can be expressed either via name-label or bridge:
# Make sure we deal with the bridge.
p_net=$(remote_execute "root@$server" \
                      "$thisdir/utils/find_network_bridge.sh" \""$p_net"\")
if [ "$p_net" == "" ]
then
    echo "Error: unable to locate (test) public network as specified by" \
         "jenkins/sites file. Ensure that the staging network exists." >&2
    exit 1
fi

#
# Create three more VPX client instances
#
template_label="\"OpenStack ${product_version}-${xb_build_number}-upgrade\""
remote_execute "root@$server" \
               "$thisdir/role-migration/client-install.sh" "$template_label" \
                                                           "$build_url" \
                                                            $devel 3

#
# tunnel to master
#
master=$(remote_execute "root@$server" \
                          "$thisdir/utils/get_master_address.sh")
tunnel_port=
establish_tunnel "$master" 8080 "$server" tunnel_port
master_url="http://localhost:$tunnel_port"


#
# shutdown the old nodes
#
roles="openstack-nova-compute openstack-nova-scheduler openstack-glance-api"
for role in $roles
do
    host=$(get_os_svc_property "$master_url" \
                               "$role" \
                               "host_fqdn")
    remote_execute "root@$host" \
                       "$thisdir/role-migration/role-based-shutdown.sh" \
                       "$role"
done


#
# wait for +1 from the geppetto-test number of 8+1
#
"$thisdir/utils/check-nodes" "$master_url" 12


#
# Now run selenium script to migrate to new VPX
#
selenium_port=$(($tunnel_port+1))
start_selenium_rc $selenium_port

set +e
python "$thisdir/role-migration/test_upgrade_wizard.py" "$master_url" \
                                                        "$selenium_port" \
                                                        "$thisdir"
code=$?
if [ "$code" -ne 0 ]
then
  parse_result "$code"
  exit $code
fi

set -e
# skip this for Dasara builds because they don't have this exact feature. 
[ $xb_build_number -ge 2000 ] && python "$thisdir/utils/check-tasks" "$master_url" || true

#
# now re-run the dashboard test
# to ensure nothing is broken
#
echo "Testing OpenStack Dashboard on: $server."
dashboard_host=$(get_os_svc_property "$master_url" \
                                     "openstack-dashboard" \
                                     "host_fqdn")

compute_host=$(get_os_svc_property "$master_url" \
                                   "openstack-nova-compute" \
                                   "host_fqdn")

dashboard_addr=$(get_os_svc_property "$master_url" \
                                     "openstack-dashboard" \
                                     "hostnetwork_ip")
"$thisdir/run-dashboard-test.sh" "$dashboard_host" \
                                 "$dashboard_addr" \
                                 "$selenium_port" \
                                 "$compute_host"
