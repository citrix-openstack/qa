#!/bin/bash
set -eu

IMAGE_NAME="$1"

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

    nova boot --image "$IMAGE_NAME" --flavor m1.tiny "$vm_name" > /dev/null
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

    if nova list | grep "$vm_name" | grep -q ACTIVE; then
        return
    fi

    echo -n "Waiting for ACTIVE status"
    while ! nova list | grep "$vm_name" | grep -q ACTIVE; do
        echo -n "."
        sleep 1
    done
    echo "done"
}


MIGRATION_COUNTER=0
SECONDS_AT_SERVER=10

start_vm "demo-instance"
list_hosts_forever | while read host; do
    wait_for_active "demo-instance"
    if vm_is_on_host "demo-instance" "$host"; then
        continue
    else
        echo "Waiting $SECONDS_AT_SERVER seconds"
        sleep $SECONDS_AT_SERVER
        echo "Asking for live migration to [$host] $MIGRATION_COUNTER migrations so far"
        nova live-migration --block-migrate "demo-instance" "$host"
        MIGRATION_COUNTER=$(expr $MIGRATION_COUNTER + 1)
    fi
done
