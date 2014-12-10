#!/bin/bash
set -eux

BUILD_ID="$BUILD_ID"


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/utils.sh


function main() {
    local node
    local node_id

    node=$(cat ${BUILD_ID}.node)

    node_id=$(echo "$node" | get_node_id)

    osci-nodepool delete "$NODE_ID"
}


main
