#!/bin/bash

set -eux

declare -a on_exit_hooks

TESTDIR=~/test_multinic
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

# Run test at nova api node
nova_api_node=$(xe vm-list --minimal tags:contains=openstack-nova-api \
                                     power-state=running \
                                     params=networks |
                sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
echo 'Running multinic test for xenserver on the api node '$nova_api_node
upload_key $nova_api_node
scp_no_hosts ~/test-xs-multinic.sh root@$nova_api_node:~/
result=`ssh_no_hosts root@$nova_api_node '~/test-xs-multinic.sh' | tail -n1`

# Parse result to get instance id
inst_id_suffix=`echo $result | cut -d';' -f1 | cut -d'-' -f2`
inst_id_prefix='i-'
inst_id=$inst_id_prefix$inst_id_suffix

# Cleanup for instance and keys
add_on_exit "ssh_no_hosts root@$nova_api_node '. $TESTDIR/novarc; euca-terminate-instances $inst_id'; rm -rf $TESTDIR"
add_on_exit "rm -f $keyfile"
add_on_exit "rm -f $keyfile.pub"

# Parse result to get instance name and number of networks
instance_name=`echo $result | cut -d';' -f1`
num_net=`echo $result | cut -d';' -f2`

# Verify NIC count against Network count
num_nic=$(xe vif-list vm-name-label=$instance_name --minimal | sed 's/[^,]//g' | wc -m)
if [ $num_net == $num_nic ];
then
    echo "Number of NICs attached to instance are as many as number of networks."
else
    echo "Number of NICs attached to instance is not equal to number of networks."
    exit 1
fi

echo "Pass."
