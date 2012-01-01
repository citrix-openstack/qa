#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"
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
gnetw_br="${GuestNetworkBridge-xapi0}"
m_nic="${XSManagementNIC-eth1}"
m_net="${ManagementNetwork-$TEST_XENSERVER_M_NET}"
p_net="${PublicNetwork-$TEST_XENSERVER_P_NET}"
m_ram="${Master_memory-700}"
s_ram="${Slave_memory-500}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
kargs="${MasterBootOptions-$MASTER_BOOT_OPTIONS}"
usr_mail="${EmailAddress-${TEST_MAIL_ACCOUNT-}}"
net_mode="${NetworkingMode-flat}"    # can be flat, flatdhcp, vlan, flatdhcp-ha
floating_ip_range="${FloatingIPRange-$FLOATING_IP_RANGE}"

master_vpx_host=
mode="${1-single}"

if [ "$mode" == "single" ]
then
    server="${Server-$TEST_XENSERVER}"

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
    remote_execute "root@$server" "$thisdir/geppetto/programmatic-geppetto-install_vpxs.sh" \
        "$build_url" "$m_nic" \""$m_net"\" "$p_net" "$devel" \
        "$ballo" "$m_ram" "$s_ram" 2 true "'$kargs'"
    master_vpx_host="$server"
elif [ "$mode" == "multi" ]
then
    # The way we handle p_net in the multi-host case has to be different
    # because the staging bridge may change from server to server.
    # This means that we have to rely on a uniquely identifiable name-label
    # to pass to the installer script, which currently supports only bridges.
    # The Result is that staging public networks for the multi-host case
    # is left unsupported for now.
    server1="${Server1-$TEST_XENSERVER_1}"
    server2="${Server2-$TEST_XENSERVER_2}"
    server3="${Server3-$TEST_XENSERVER_3}"
    server4="${Server4-$TEST_XENSERVER_4}"
    pids=
    install "$server1" "$m_nic" 1 "$kargs" "$m_ram" 1 "$s_ram" "" "192.168.1.2"
    wait_for "$pids" # Wait for the first one to succeed, to allow the local
                     # cache to populate.  There's no point trying to download
                 # the VPX in parallel across all machines at once.
    install "$server2" "$m_nic" 0 "" "" 3 "$s_ram" 1 "192.168.1.3"
    install "$server3" "$m_nic" 0 "" "" 3 "$s_ram" 1 "192.168.1.4"
    install "$server4" "$m_nic" 0 "" "" 1 "$s_ram" 1 "192.168.1.5"
    wait_for "$pids"
    master_vpx_host="$server1"
else
    echo "Mode not supported, bailing!"
    exit 1
fi

## THIS IS A HACK, BUT IT'LL DO FOR THE TIME BEING ##
if [ "$net_mode" != "flat" ]
then
    server="$TEST_XENSERVER_2"
fi

# TEST OPENSTACK CLOUD DEPLOYMENT
master=$(remote_execute "root@$master_vpx_host" \
                        "$thisdir/utils/get_master_address.sh")
port=
establish_tunnel "$master" 8080 "$master_vpx_host" port
master_url="http://localhost:$port"

# Check that we've had 2 + 1 nodes register.  This is what install_vpxs.sh
# should have installed. The +1 comes from the master, that also registers
# with itself.
"$thisdir/utils/check-nodes" "$master_url" 3
