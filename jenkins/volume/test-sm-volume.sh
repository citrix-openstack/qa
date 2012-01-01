#!/bin/bash

set -eux

declare -a on_exit_hooks

TESTDIR=~/testsm
ATTACHDEV=/dev/sde
FLAGDIR=/etc/openstack/volume
SRNAME='func-vol'
instnum=0
inst=0

user="sm_user"
pass="sm_pass"
tenant="sm_tenant"

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

create_backend()
{
    nova-manage sm flavor_create gold "Not all that glitters"
    ans=$(nova-manage sm flavor_list | grep 'gold')
    add_on_exit "nova-manage sm flavor_delete gold"

    echo -e "y" | nova-manage sm backend_add gold nfs name_label=$SRNAME server=copper.eng.hq.xensource.com serverpath=/func-volume-test
    backend=$(nova-manage sm backend_list | grep $SRNAME | cut -f1)
    add_on_exit "nova-manage sm backend_remove $backend"
}

restart_volume()
{
    VOLWORKER=`os-vpx-get-worker-for volume`
    ssh_no_hosts root@$VOLWORKER 'service openstack-nova-volume restart'
    ans=$(ssh_no_hosts root@$VOLWORKER 'service openstack-nova-volume status | grep 'running'')
}

restart_compute()
{
    COMPWORKER=`os-vpx-get-worker-for compute`
    ssh_no_hosts root@$COMPWORKER 'service openstack-nova-compute stop'
    ssh_no_hosts root@$COMPWORKER 'service openstack-nova-compute start'
    ans=$(ssh_no_hosts root@$COMPWORKER 'service openstack-nova-compute status | grep 'running'')

}

test_volume()
{
    local nova="nova --username $user --apikey $pass --projectid $tenant"
    $nova volume-create 1
    
    vol=$($nova volume-list | tail -n 2 | sed -n '1p' | awk '{print $2}')
    echo $vol
    
    echo '=================================================================='
    echo 'Creating volume...'
    echo $vol
    sleep 20
    $nova volume-list
    
    echo 'Volume '$vol' created.'

    echo 'Attaching volume '$vol ' to instance '$inst
    $nova volume-attach $inst $vol $ATTACHDEV
    
    sleep 40
    echo '================================================================='
    $nova volume-list
    echo 'Detaching volume '$vol
    $nova volume-detach $inst $vol
    
    sleep 40
    $nova volume-list
    echo 'Deleting volume...'
    $nova volume-delete $vol
    
    i=1
    while [ $i -le 10 ]
    do
        echo 'Waiting for volume delete (iSCSI could take a while)...'
        sleep 30
        ans=$($nova volume-list | cut -b 2-5 | grep $vol || true)
        if [ -z "$ans" ]
        then
            break
        fi
        i=$(( $i + 1 ))
    done
    if [ "$ans" ]
    then
        echo 'Could not delete volume'
        exit 1
    fi
}

create_instance()
{
    local nova="nova --username $user --apikey $pass --projectid $tenant"
    inst=$($nova boot --flavor 1 --image 3 ubuntu | grep -w "id" | awk '{print $4}')
    add_on_exit "$nova delete $inst"
    sleep 60
    isrunning=$($nova list | grep -w " $inst " | grep 'ACTIVE' || true)
    instnum=$(printf '%x' $inst)
    echo $instnum
    i=1
    while [ $i -le 10 ]
    do
        echo 'Waiting...'
        sleep 30
	echo "[====================================================================================]"
	$nova list
	echo "[====================================================================================]"
        isrunning=$($nova list | grep -w " $inst " | grep 'ACTIVE' || true)

        if [ -n "$isrunning" ]
        then
            break
        fi
        i=$(( $i + 1 ))
    done

    if [ $i -eq 30 ]
    then
        isrunning=$($nova list | grep -w " $inst " | grep 'ACTIVE' || true)
    fi

    echo 'Instance created'
   
}

add_on_exit "cd ~/; rm -rf $TESTDIR"

keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi

master_url="http://master:8080"
xensm_local_vol="false"
xensm_driver="nova.volume.xensm.XenSMDriver"
iscsi_local_vol="true"
iscsi_driver="nova.volume.driver.ISCSIDriver"
thisdir=$(dirname "$0")


mkdir -p $TESTDIR; cd $TESTDIR
tenantexist=$(keystone-manage tenant list | grep "$tenant" || true)
if [ -z "$tenantexist" ]
then
    os-vpx-add-tenant "$tenant"
fi
userexist=$(keystone-manage user list | grep "$user" || true)
if [ -z "$userexist" ]
then
    os-vpx-add-user "$tenant" "$user" "$pass" \
                    "Member,0 netadmin,0 projectmanager,0 sysadmin,0"
fi
os-vpx-rc "$user" "$pass"
. novarc





create_instance

# iSCSI Test
VOLWORKER=`os-vpx-get-worker-for volume`
upload_key $VOLWORKER

"$thisdir/set_globals" "$master_url" \
    "USE_LOCAL_VOLUMES=$iscsi_local_vol,\
    VOLUME_DRIVER=$iscsi_driver"

COMPWORKER=`os-vpx-get-worker-for compute`
upload_key $COMPWORKER

#Service restart should be triggered automatically
sleep 120

test_volume

# SM Test
create_backend

"$thisdir/set_globals" "$master_url" \
    "USE_LOCAL_VOLUMES=$xensm_local_vol,\
    VOLUME_DRIVER=$xensm_driver"

#Service restart should be triggered automatically
sleep 120

test_volume

echo 'Volume test complete'
