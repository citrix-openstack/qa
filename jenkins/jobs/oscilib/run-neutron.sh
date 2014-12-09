#!/bin/bash
set -eu


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh

NODE=""
HELD_NODE=""


function finish {
    if [ -n "$HELD_NODE" ]; then
        echo "Deleting held node"
        osci-nodepool delete $(cat "$NODE" | get_node_id)
    fi
}


function main() {
    trap finish EXIT

    echo "Waiting for a ready node"
    while true; do
        NODE=$(osci-nodepool list | get_ready_node)
        if [ -z "$NODE" ]; then
            echo "."
            sleep 1
            continue
        fi
        echo "Got one!"
        break
    done

    NODE_ID=$(echo "$NODE" | get_node_id)
    NODE_IP=$(echo "$NODE" | get_node_ip)

    osci-nodepool hold "$NODE_ID" && HELD_NODE="$NODE"

    cat << EOF
Node ID: $NODE_ID
Node IP: $NODE_IP
EOF
}


main
