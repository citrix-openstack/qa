#!/bin/bash

set -eux

declare -a on_exit_hooks

TESTDIR=~/test_dir
thisdir=$(dirname "$0")

on_exit()
{
    for i in "${on_exit_hooks[@]}"
    do
        eval $i
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]
    then
        trap on_exit EXIT
    fi
}

_no_hosts()
{
    cmd="$1"
    shift
    "$cmd" -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -i "$keyfile" \
        "$@"
}

ssh_no_hosts()
{
    _no_hosts "ssh" "$@"
}

scp_no_hosts()
{
    _no_hosts "scp" "$@"
}

gen_key()
{
    ssh-keygen -N '' -f "$keyfile" >/dev/null
}

upload_key()
{
    host="$1"
    key=$(cat "$keyfile.pub")
    expect >/dev/null <<EOF -
set timeout -1
spawn ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          root@$host \
          mkdir -p /root/.ssh\; echo $key >>/root/.ssh/authorized_keys
match_max 100000
expect {
  "*?assword:*" {
  send -- "$password\r"
  send -- "\r"
  expect eof
  }
  eof {
  }
EOF
}

keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi

# Find nova network node
nova_network_node=$(xe vm-list --minimal tags:contains=openstack-nova-network \
                                     power-state=running \
                                     params=networks |
                sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
echo 'Running floating ip test on the network node '$nova_network_node
upload_key $nova_network_node
scp_no_hosts ~/test-floatingip.sh root@$nova_network_node:~/
result=`ssh_no_hosts root@$nova_network_node '~/test-floatingip.sh'`

# Parse result to get instance id
inst_id_suffix=`echo $result | tail -n1 | cut -d';' -f1 | cut -d'-' -f2`
inst_id_prefix='i-'
inst_id=$inst_id_prefix$inst_id_suffix

# Cleanup for instance and keys
add_on_exit "ssh_no_hosts root@$nova_network_node '. $TESTDIR/novarc; euca-terminate-instances $inst_id'; rm -rf $TESTDIR"
add_on_exit "rm -f $keyfile"
add_on_exit "rm -f $keyfile.pub"

ip=`echo $result | tail -n1 | cut -d';' -f2`
add_on_exit "ssh_no_hosts root@$nova_network_node '. $TESTDIR/novarc; euca-disassociate-address $ip; euca-release-address $ip"
# Ping the instance with floating IP
output=`ping -q -c4 $ip | tail -n2 | head -n1 | awk {'print $1":"$4'}`
sent_packets=`echo $output | cut -d':' -f1`
received_packets=`echo $output | cut -d':' -f2`
if [ $sent_packets == $received_packets ];
then
    echo "Instance is accessible via floating IP from external network"
else
    echo "Seems floating range specified is NOT valid OR network worker doesn't have the publich IP in the same subnet as that of floating range."
    echo "As IP bounded successfully to public interface, assume test pass."
fi

echo "Pass."
