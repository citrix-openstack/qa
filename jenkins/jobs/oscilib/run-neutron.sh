#!/bin/bash
set -eu


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh

HELD_NODE=""


function finish {
    if [ -n "$HELD_NODE" ]; then
        echo "Deleting held node"
        osci-nodepool delete $(echo "$HELD_NODE" | get_node_id)
    fi
}


function main() {
    local node
    trap finish EXIT

    echo "Waiting for a ready node"
    while true; do
        node=$(osci-nodepool list | get_ready_node)
        if [ -z "$node" ]; then
            echo "."
            sleep 5
            continue
        fi
        echo "Got one!"
        break
    done

    NODE_ID=$(echo "$node" | get_node_id)
    NODE_IP=$(echo "$node" | get_node_ip)

    osci-nodepool hold "$NODE_ID" && HELD_NODE="$node"

    cat << EOF
Node ID: $NODE_ID
Node IP: $NODE_IP
EOF
}


main
