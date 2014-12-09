#!/bin/bash
set -eu


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh


function main() {
    NODE=""

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

    cat << EOF
Node ID: $NODE_ID
Node IP: $NODE_IP
EOF
}


main
