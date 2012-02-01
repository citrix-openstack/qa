#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"
. "$thisdir/common-vpx.sh"

enter_jenkins_test

server1="${Server1-$TEST_XENSERVER_1}"
server2="${Server2-$TEST_XENSERVER_2}"
server3="${Server3-$TEST_XENSERVER_3}"
server4="${Server4-$TEST_XENSERVER_4}"
m_net="${ManagementNetwork-$TEST_XENSERVER_M_NET}"
p_net="${PublicNetwork-$TEST_XENSERVER_P_NET}"
usr_mail="${EmailAddress-$TEST_MAIL_ACCOUNT}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
devel="${Devel-false}"
skipd=false
gnetw="${GuestNetwork-$GUEST_NETWORK}"
password="${Password-$XS_ROOT_PASSWORD}"

echo "Installing VPXs and deploy using Geppetto on: $server1."
"$thisdir/run-geppetto-test.sh" multi

# Establish communication to VPX Master
master=$(remote_execute "root@$server1" \
                        "$thisdir/utils/get_master_address.sh")
port=
establish_tunnel "$master" 8080 "$server1" port
master_url="http://localhost:$port"

echo "Testing if Remote Logging is working on: $server1."
"$thisdir/run-syslog-test.sh" $server1

echo "Testing XenCenter Tags updates"
"$thisdir/run-xc-tags-test.sh" $server1 $server2 $server3 $server4

echo "Testing OpenStack Glance"
glance_host=$(get_os_svc_property "$master_url" \
                                   "openstack-glance-api" \
                                   "host_fqdn")

glance_addr=$(get_os_svc_property "$master_url" \
                                   "openstack-glance-api" \
                                   "hostnetwork_ip")

"$thisdir/run-glance-stream-test.sh" "$glance_host" "$glance_addr" "$port"

echo "Testing XenServer Fast Cloning"
keystone_host=$(get_os_svc_property "$master_url" \
                                    "openstack-keystone-auth" \
                                    "host_fqdn")

keystone_addr=$(get_os_svc_property "$master_url" \
                                    "openstack-keystone-auth" \
                                    "hostnetwork_ip")

nova_host=$(get_os_svc_property "$master_url" \
                                "openstack-nova-api" \
                                "host_fqdn")

nova_addr=$(get_os_svc_property "$master_url" \
                                "openstack-nova-api" \
                                "hostnetwork_ip")

"$thisdir/run-fast-cloning.sh" "$keystone_host" "$keystone_addr" \
                               "$nova_host" "$nova_addr" "$port"


echo "Testing OpenStack Dashboard"
dashboard_host=$(get_os_svc_property "$master_url" \
                                     "openstack-dashboard" \
                                     "host_fqdn")
                                     
compute_host=$(get_os_svc_property "$master_url" \
                                   "openstack-nova-compute" \
                                   "host_fqdn")

dashboard_addr=$(get_os_svc_property "$master_url" \
                                     "openstack-dashboard" \
                                     "hostnetwork_ip")
# Disable this for now
#"$thisdir/run-dashboard-test.sh" "$dashboard_host" \
#                                 "$dashboard_addr" \
#                                 "$port" \
#                                 "$compute_host"

echo "Testing if Master VPX backup/restore is working on: $server1."
"$thisdir/run-master-upgrade-test.sh" $server1

echo "Testing if Role Migration is working on: $server1."
"$thisdir/run-role-migration-test.sh" $server1

# Add other tests here (or in the right order, from the least destructive to
# the most destructive). E.g. put tests that change the deployment, like role
# migration at the end of the chain.
