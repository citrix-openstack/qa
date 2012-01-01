#!/bin/bash

set -eux

declare -a on_exit_hooks

TESTDIR=~/test_dir
FLAGDIR=/etc/openstack/guest-network
USER=test_user
PASS=test_pass
PROJECT=test_project
TENANT_BRIDGE=xenbr0
tenantexist=
userexist=

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

# Create a fake user/project for CLI tools
mkdir -p $TESTDIR; cd $TESTDIR
tenantexist=$(keystone-manage tenant list | grep "$PROJECT" || true)
if [ -z "$tenantexist" ]
then
    os-vpx-add-tenant "$PROJECT"
fi

userexist=$(keystone-manage user list | grep "$USER" || true)
if [ -z "$userexist" ]
then
    os-vpx-add-user "$PROJECT" "$USER" "$PASS" \
                    "Member,0 netadmin,0 projectmanager,0 sysadmin,0"
fi

os-vpx-rc "$USER" "$PASS"
. novarc

# Check if mykey is already present
key=$(euca-describe-keypairs | grep "mykey" | awk {'print $2'} || true)
if [ -z "$key" ]
then
    euca-add-keypair mykey > mykey.priv
    chmod 600 mykey.priv
fi

# Create an instance
create_instance
instance_name="instance-"`echo $inst | cut -d'-' -f2`
export NOVA_USERNAME='root'
export NOVA_PROJECT_ID='Administrator'
export NOVA_PASSWORD='citrix'

floating_ip=`nova floating-ip-create | grep None | awk {'print $2'}`
instance_id=`nova list | grep ACTIVE | head -n1 | awk {'print $2'}`
nova add-floating-ip $instance_id $floating_ip
sleep 4
echo "Verifying if floating IP is added to public interface in network worker." 
configured_ip=$(ip addr show | grep "$floating_ip" | awk {'print $2'} | cut -d'/' -f1 || true)
if [ -z "$configured_ip" ]
then
    echo $instance_name";"$floating_ip
    exit 1
else
    echo "Found the floating IP bounded to public interface in network worker."
    allocated_instance_id=`nova floating-ip-list | awk {'print $4'} | grep $instance_id | tail -n1`
    if [ $instance_id == $allocated_instance_id ]
    then
        echo $instance_name";"$floating_ip
    fi
fi
