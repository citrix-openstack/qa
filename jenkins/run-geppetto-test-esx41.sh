#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common-esx41.sh"
autosite="${AUTOSITE-false}"
if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

password="${Password-$TEST_ESX_SINGLE_TEST_PASSWORD}"
devel="${Devel-false}"
skipd="${ShortRun-false}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
usr_mail="${EmailAddress-${TEST_MAIL_ACCOUNT-}}"
numports="${NumPorts-$TEST_ESX_SINGLE_TEST_NUMPORTS}"
gnetw="${GuestNetwork-$GUEST_NETWORK}"
p_net="${PublicNetwork-$TEST_ESX_SINGLE_TEST_P_NET}"

echo "build_url inside run-geppetto-test-esx41.sh is --> " $build_url
echo "numports is ---> " $numports

master_vpx_host=
mode="${1-single}"
if [ "$mode" == "single" ]; then
    echo "Firing tests for single host mode."
    add_on_exit ""
    server="${Server-$TEST_ESX_SINGLE_TEST_SERVER}"
    "$thisdir/utils/install_vpxs_esx41.sh" "$server" \
        "$password" "$numports" "$build_url" "$devel"
    master_vpx_host="$server"
elif [ "$mode" == "multi" ]; then
    # Fill this in later when putting in multihost ESX testing.
    echo "To be implemented.."
fi

# TEST OPENSTACK CLOUD DEPLOYMENT
#master=$(remote_execute "root@$master_vpx_host" \
#                        "$thisdir/utils/get_master_address.sh")
# We know the master's ip.. we hardcode it for now.
master="192.168.128.2"
port=
establish_tunnel "$master" 8080 "$master_vpx_host" port
master_url="http://localhost:$port"

# Check that we've had 8 + 1 nodes register.  This is what install_vpxs_esx41.sh
# should have installed. The +1 comes from the master, that also registers 
# with itself.
"$thisdir/utils/check-nodes" "$master_url" 9

# Set global configs before deplyoing any role. Changing flags values  
# should happen here; argv[2] is a comma-separated string of keyvalue
# pairs. If values have spaces, quote them with '

"$thisdir/utils/set_globals" "$master_url" \
                             "DASHBOARD_SMTP_SVR=$smtp_svr,\
                              GUEST_NETWORK_BRIDGE=$p_net"

selenium_port=$(($port+1))
start_selenium_rc "$selenium_port"

set +e
python "$thisdir/geppetto/test_master.py" "$master_url" \
                                          "$selenium_port" \
                                          "$thisdir" \
                                          "$password" \
                                          "$gnetw" "8"
code=$(parse_result "$?")
code=0
exit $code
