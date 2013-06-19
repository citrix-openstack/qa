#!/bin/bash

set -eu

function print_usage_and_die
{
    local errmsg

    errmsg=${1:-}
cat >&2 << EOF
$1

usage: $0 SERVER NETDEF

Setup uniquely named xenserver network mapped to physical devices

positional arguments:
 SERVER         XenServer
 NETDEF         Network definition name:phy:vlan

Example:

Set up datacenter-pub as a non-tagged on eth1:

    $0 xenserver1 datacenter-pub:eth1:-1

and datacenter-vm as vlan 16 on eth1:

    $0 xenserver1 datacenter-vm:eth1:16

EOF
exit 1
}

function bash_on() {
    local server

    server="$1"
    shift

    ssh -q \
        -o Batchmode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        "$server" bash -s -- "$@"
}


function assert_unique_network() {
    local name

    name="$1"

    network=$(xe network-list name-label="$name" --minimal)

    if [ -z "$network" ]; then
        echo "The given network does not exist" >&2
        exit 1
    else
        if echo "$network" | grep -q ","; then
            echo "Multiple networks with the name $name" >&2
            exit 1
        fi
    fi
}

function create_network() {
    local name
    local dev
    local vlan

    name=$(echo "$1" | cut -d":" -f 1)
    dev=$(echo "$1" | cut -d":" -f 2)
    vlan=$(echo "$1" | cut -d":" -f 3)

    local network
    local pif

    network=$(xe pif-list VLAN="$vlan" device="$dev" params=network-uuid --minimal)

    if [ -z "$network" ]; then
        if [ "$vlan" = "-1" ]; then
            echo "Not implemented" >&2
            exit 1
        fi

        network=$(xe network-create name-label="$name")
        pif=$(xe pif-list device="$dev" VLAN=-1 --minimal)
        xe vlan-create network-uuid=$network pif-uuid=$pif vlan=$vlan
    fi

    xe network-param-set uuid=$network name-label="$name"

    assert_unique_network "$name"
}

if [ "bash" == "$0" ]; then
    set -eux
    $@
else
    SERVER="${1-$(print_usage_and_die "No XenServer specified")}"
    NETDEF="${2-$(print_usage_and_die "No network definition given")}"

    cat $0 | bash_on "$SERVER" create_network "$NETDEF"
fi
