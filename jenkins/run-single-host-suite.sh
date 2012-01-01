#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

devel="${Devel-false}"
autosite="${AUTOSITE-false}"
password="${Password-$XS_ROOT_PASSWORD}"

if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

server="${Server-$TEST_XENSERVER}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
usr_mail="${EmailAddress-$TEST_MAIL_ACCOUNT}"
devel="${Devel-false}"
ballo="${Ballooning-false}"
m_ram="${Master_memory-700}"
s_ram="${Slave_memory-500}"
skipd="${ShortRun-false}"
gnetw="${GuestNetwork-$GUEST_NETWORK}"


echo "Installing VPXs and deploy using Geppetto on: $server."
"$thisdir/run-geppetto-test.sh"

echo "Testing if Remote Logging is working on: $server."
"$thisdir/run-syslog-test.sh"

echo "Testing XenCenter Tags updates on: $server."
"$thisdir/run-xc-tags-test.sh"

echo "Testing OpenStack Glance on: $server."
"$thisdir/run-glance-stream-test.sh"

echo "Testing XenServer Fast Cloning on: $server."
"$thisdir/run-fast-cloning.sh"

echo "Testing OpenStack Dashboard on: $server."
"$thisdir/run-dashboard-test.sh"

echo "Testing Multi-NIC Support on: $server."
"$thisdir/run-multinic-test.sh"

echo "Testing Floating IP Support on: $server."
"$thisdir/run-floatingip-test.sh"

echo "Testing Keystone Support on: $server."
"$thisdir/run-keystone-integration.sh"

#echo "Testing if Master VPX backup/restore is working on: $server."
"$thisdir/run-master-upgrade-test.sh"

#echo "Testing if Role Migration is working on: $server."
"$thisdir/run-role-migration-test.sh"

# Add other tests here (or in the right order, from the least destructive to
# the most destructive). E.g. put tests that change the deployment, like role
# migration at the end of the chain.
