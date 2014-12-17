#!/bin/bash
set -eu

BUILD_ID="$BUILD_ID"


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh


function main() {
    local node

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

    osci-nodepool hold "$NODE_ID"

    cat << EOF
Node ID: $NODE_ID
Node IP: $NODE_IP
EOF
    echo "$node" > ${BUILD_ID}.node
    echo "Node file created: ${BUILD_ID}.node"

    echo "Running tests..."
    nohup sudo \
        -u osci \
        -i \
        /opt/osci/env/bin/osci-run-tests \
            exec \
            jenkins \
            $NODE_IP \
            refs/changes/97/139097/2 \
            openstack/ironic \
            https://github.com/matelakat/xenapi-os-testing </dev/null
}


main
