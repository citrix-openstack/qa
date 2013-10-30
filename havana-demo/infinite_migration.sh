#!/bin/bash
set -eu

cd /opt/stack/devstack


set +u
. openrc admin
set -u

function start_vm() {
    local vm_name

    vm_name="$1"

    if nova list | grep -q "$vm_name"; then
        echo "ERROR: instance [$vm_name] already exists!"
        exit 1
    fi

    nova boot --image cirros-0.3.0-x86_64-disk --flavor m1.tiny "$vm_name" > /dev/null
}

function list_hosts_forever() {
    while true; do
        nova host-list | grep compute | cut -d"|" -f 2 | tr -d " "
    done
}

function vm_is_on_host() {
    local vm_name
    local host

    vm_name="$1"
    host="$2"

    nova show "$vm_name" | grep "OS-EXT-SRV-ATTR:host" | grep -q "$host"
}

function wait_for_active() {
    local vm_name
    
    vm_name="$1"

    echo -n "Waiting for the instance to become ACTIVE"
    while ! nova list | grep "$vm_name" | grep -q ACTIVE; do
        echo -n "."
        sleep 1
    done
    echo "done"
}


start_vm "testbox"
list_hosts_forever | while read host; do
    wait_for_active "testbox"
    if vm_is_on_host "testbox" "$host"; then
        echo "Instance is on [$host]"
    else
        echo "Waiting 10 seconds"
        sleep 10
        echo "Asking for live migration to [$host]"
        nova live-migration --block-migrate "testbox" "$host"
    fi
done
