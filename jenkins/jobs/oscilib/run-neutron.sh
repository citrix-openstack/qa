#!/bin/bash
set -eu


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh


function main() {
    READY_NODE=""

    echo -n "Holding a node "
    while true; do
        READY_NODE=$(get_ready_node)
        if [ -z "$READY_NODE" ]; then
            echo -n "."
            sleep 1
            continue
        fi
        echo "OK"
        break
    done

    NODE_ID=$(echo "$READY_NODE" | get_node_id)
    NODE_IP=$(echo "$READY_NODE" | get_node_ip)

    cat << EOF
Node ID: $NODE_ID
Node IP: $NODE_IP
EOF
}


main
