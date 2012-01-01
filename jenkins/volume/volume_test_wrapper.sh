#!/bin/bash

set -eu

SRNAME='func-vol'

declare -a on_exit_hooks

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

keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi

# This is there because today, nova volume (SM driver) does not forget SRs when the
# service is stopped. Once that code is in, this should be changed to a test
# whether the SR has been forgotten.
cleanup_sr()
{
    echo 'SR cleanup post test'
    sr_uuid=$(xe sr-list name-label="$SRNAME" --minimal)
    if [ "$sr_uuid" = "" ]
    then
        echo 'SR not found...'
        return
    fi
    pbd_uuid=$(xe pbd-list sr-uuid="$sr_uuid" --minimal)
    if [ "$pbd_uuid" != "" ]
    then
        xe pbd-unplug uuid="$pbd_uuid"
    fi
    xe sr-forget uuid="$sr_uuid"
    # Verify
    sleep 10
    sr_uuid=$(xe sr-list name-label="$SRNAME" --minimal)
    if [ "$sr_uuid" != "" ]
    then
        echo 'Could not forget SR'
        exit 1
    fi
}

nova_api_node=$(xe vm-list --minimal tags:contains=openstack-nova-api \
                                     power-state=running \
                                     params=networks |
                sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
echo 'Running volume test on the api node '$nova_api_node
upload_key $nova_api_node
add_on_exit cleanup_sr
scp_no_hosts ~/test-sm-volume.sh root@$nova_api_node:~/
scp_no_hosts ~/set_globals root@$nova_api_node:~/
scp_no_hosts ~/common.py root@$nova_api_node:~/

ssh_no_hosts root@$nova_api_node '~/test-sm-volume.sh'
