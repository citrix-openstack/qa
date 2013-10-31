#!/bin/bash
set -eu

cd /opt/stack/devstack

set +u
. openrc admin
set -u

function start_vm() {
    local vm_name
    local image_name

    vm_name="$1"
    image_name="$2"

    if nova list | grep -q "$vm_name"; then
        echo "ERROR: instance [$vm_name] already exists!"
        exit 1
    fi

    nova boot --image "$image_name" --flavor m1.tiny "$vm_name"
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

    echo -n "Waiting for ACTIVE status"
    while ! nova list | grep "$vm_name" | grep -q ACTIVE; do
        echo -n "."
        sleep 1
    done
    echo "done"
}

function image_exists() {
    local image_name

    image_name="$1"

    glance image-list | grep -q "$image_name"
}

function vm_exists() {
    local vm_name

    vm_name="$1"

    nova list | grep -q "$vm_name"
}

function print_vm_ip() {
    local vm_name

    vm_name="$1"

    nova show demo-instance | grep "private network" | tr -d " " | cut -d"|" -f3
}

function image_is_active() {
    local image_name

    image_name="$1"

    glance image-list | grep "$image_name" | grep -q "active"
}

function remove_image() {
    local image_name

    image_name="$1"

    if image_exists "$image_name"; then
        glance image-delete "$image_name"

        while image_exists "$image_name"; do
            sleep 1
        done
    fi
}

function upload_image() {
    local image_url
    local image_name

    image_url="$1"
    image_name="$2"

    glance image-create \
        --disk-format=vhd \
        --container-format=ovf \
        --copy-from="$image_url" \
        --is-public=True \
        --name="$image_name"

    while ! image_is_active "$image_name"; do
        sleep 1
    done
}

function remove_vm() {
    local vm_name

    vm_name="$1"

    if vm_exists "$vm_name"; then
        nova delete "$vm_name"
    fi

    while vm_exists "$vm_name"; do
        sleep 1
    done
}


MIGRATION_COUNTER=0
SECONDS_AT_SERVER=10


remove_image "demo-image"

upload_image \
    "http://copper.eng.hq.xensource.com/havana-demo/streamer-coalesced.vhd.tgz" \
    "demo-image"

remove_vm "demo-instance"

start_vm "demo-instance" "demo-image"

wait_for_active "demo-instance"

list_hosts_forever | while read host; do
    if vm_is_on_host "demo-instance" "$host"; then
        continue
    else
        echo "Private address of the vm is: $(print_vm_ip demo-instance)"
        echo "Asking for live migration to [$host] ($MIGRATION_COUNTER migrations so far)"
        nova live-migration --block-migrate "demo-instance" "$host"
        MIGRATION_COUNTER=$(expr $MIGRATION_COUNTER + 1)
        wait_for_active "demo-instance"
        echo "Waiting $SECONDS_AT_SERVER seconds"
        sleep $SECONDS_AT_SERVER
    fi
done
