#!/bin/bash

set -eux

declare -a on_exit_hooks

TESTDIR=~/test_multinic
FLAGDIR=/etc/openstack/guest-network
MULTINIC_USER=multinic-user
MULTINIC_PASS=multinic-pass
MULTINIC_PROJECT=multinic-project
TENANT_BRIDGE=xenbr0
tenantexist=
userexist=
network_1=10.0.0
network_2=10.1.0
network_3=10.2.0

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
    add_on_exit "rm -f $keyfile"
    add_on_exit "rm -f $keyfile.pub"
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

restart_network()
{
    # Using restart gives the infamous "Can't lock the lock file 
    # "/var/lock/subsys/openstack-nova-network". Is another instance running"

    ssh_no_hosts root@$NETWORKER 'service openstack-nova-network stop'
    sleep 10
    ssh_no_hosts root@$NETWORKER 'service openstack-nova-network start'
    ans=$(ssh_no_hosts root@$NETWORKER 'service openstack-nova-network status | grep 'running'')
}

restart_compute()
{
    ssh_no_hosts root@$COMPWORKER 'service openstack-nova-compute restart'
    ans=$(ssh_no_hosts root@$COMPWORKER 'service openstack-nova-compute status | grep 'running'')

}

create_instance()
{
    inst=`euca-run-instances ubuntu -k mykey -t m1.tiny | grep -w -o --only-matching 'i-[0-9,a-f]*'`
    #add_on_exit "euca-terminate-instances $inst"
    isrunning=$(euca-describe-instances | grep "$inst" | grep 'running' || true)
    i=1
    while [ $i -le 10 ]
    do
        echo 'Waiting...'
        sleep 30
        isrunning=$(euca-describe-instances | grep "$inst" | grep 'running' || true)
        if [ -n "$isrunning" ]
        then
            break
        fi
        i=$(( $i + 1 ))
    done
    isrunning=$(euca-describe-instances | grep "$inst" | grep 'running' || true)
    if [ -n "$isrunning" ]
    then
        echo 'Instance created'
    fi
}

ping_address()
{
    instance_address=$1
    ping_result=`ssh_no_hosts root@$NETWORKER 'ping -q -c4 '$1' | tail -n2 | head -n1'`
    sent_packets=`echo $ping_result | cut -d' ' -f1`
    received_packets=`echo $ping_result | cut -d' ' -f4`
    if [ $sent_packets == $received_packets ];
    then
        echo "Attempt to ping $instance_address is success."
    else
        echo "Attempt to ping $instance_address failed. In case of Flat networking, please check if gateway ip is configured on network worker."
        # This failure might be because of misconfigured bridge/gateway.
        # exit 1
    fi
}

check_network_segment()
{
    if [ "$3" == "$2" ]
    then
        echo "This NIC "$1" is configured with correct network segment "$2
    else
        echo "This NIC "$3" is not configured correctly."
        exit 1
    fi
}

#add_on_exit "cd ~/; rm -rf $TESTDIR"

keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi

# We set configuration flags for networker based on test case
NETWORKER=`os-vpx-get-worker-for network`
upload_key $NETWORKER

# Not yet updating configuration flags for compute worker.
COMPWORKER=`os-vpx-get-worker-for compute`
upload_key $COMPWORKER

# Create a fake user/project for CLI tools
mkdir -p $TESTDIR; cd $TESTDIR
tenantexist=$(keystone-manage tenant list | grep "$MULTINIC_PROJECT" || true)
if [ -z "$tenantexist" ]
then
    os-vpx-add-tenant "$MULTINIC_PROJECT"
fi

userexist=$(keystone-manage user list | grep "$MULTINIC_USER" || true)
if [ -z "$userexist" ]
then
    os-vpx-add-user "$MULTINIC_PROJECT" "$MULTINIC_USER" "$MULTINIC_PASS" \
                    "Member,0 netadmin,0 projectmanager,0 sysadmin,0"
fi

os-vpx-rc "$MULTINIC_USER" "$MULTINIC_PASS" "$MULTINIC_PROJECT"
. novarc

nova-manage network create --label public-test --fixed_range_v4 10.1.0.0/24 --num_networks=1 --network_size=8 --bridge=$TENANT_BRIDGE
add_on_exit "nova-manage network delete --network=10.1.0.0/29"
nova-manage network create --label private-test --fixed_range_v4 10.2.0.0/24 --num_networks=1 --network_size=8 --bridge=$TENANT_BRIDGE
add_on_exit "nova-manage network delete --network=10.2.0.0/29"

# Check if mykey is already present
key=$(euca-describe-keypairs | grep "mykey" | awk {'print $2'} || true)
if [ -z "$key" ]
then
    euca-add-keypair mykey > mykey.priv
    chmod 600 mykey.priv
fi

#Test Flat Networking
export NOVA_USERNAME=$MULTINIC_USER
export NOVA_PASSWORD=$MULTINIC_PASS
export NOVA_PROJECT_ID=$MULTINIC_PROJECT

# ssh_no_hosts root@$NETWORKER 'sed -i -e "s/^NETWORK_MANAGER.*/NETWORK_MANAGER=nova.network.manager.FlatManager/" '$FLAGDIR
# restart_network

# Create instance
create_instance
#inst=i-00000004
inst_id_hex=`echo $inst | cut -c9-`
# Convert hex instance id to decimal
inst_id=$(printf "%d" 0x${inst_id_hex})
id=`nova show $inst_id | grep "^| id " | awk {'print $4'}`

# Get IP addresses of assigned to the instance
instance_address1=`nova list | grep "^| $id" | cut "-d|" -f5 | cut "-d;" -f3 | cut "-d=" -f2`
instance_address2=`nova list | grep "^| $id" | cut "-d|" -f5 | cut "-d;" -f2 | cut "-d=" -f2`
instance_address3=`nova list | grep "^| $id" | cut "-d|" -f5 | cut "-d;" -f1 | cut "-d=" -f2`
echo "Found following IP addresses configured for instance "$inst" "$instance_address1", "$instance_address2", "$instance_address3

# Ping all 3 addresses of instance
ping_address $instance_address1
ping_address $instance_address2
ping_address $instance_address3

# Get network segments for all 3 addresses
nic1_segment=`echo $instance_address1 | cut -c-6`
nic2_segment=`echo $instance_address2 | cut -c-6`
nic3_segment=`echo $instance_address3 | cut -c-6`

# Check network segment for all 3 addresses
check_network_segment $instance_address1 $nic1_segment $network_1
check_network_segment $instance_address2 $nic2_segment $network_2
check_network_segment $instance_address3 $nic3_segment $network_3

# Retrieve network count
instance_name="instance-"`echo $inst | cut -d'-' -f2`
(( net_count = `/usr/local/bin/nova-manage network list | wc -l` - 1 ))
echo $instance_name";"$net_count
