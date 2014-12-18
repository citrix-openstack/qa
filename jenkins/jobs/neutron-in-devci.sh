#!/bin/bash
set -eux

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh
. $THIS_DIR/oscilib/utils.sh

XENAPI_OS_TESTING_REPO="https://github.com/matelakat/xenapi-os-testing"

function main() {
    check_out_infra
    enter_infra_osci
    ./scp.sh dev_ci $THIS_DIR/oscilib/utils.sh utils.sh
    ./scp.sh dev_ci $THIS_DIR/oscilib/run-neutron.sh run-neutron.sh
    ./scp.sh dev_ci $THIS_DIR/oscilib/kill-node.sh kill-node.sh
    ./ssh.sh dev_ci XENAPI_OS_TESTING_REPO=$XENAPI_OS_TESTING_REPO BUILD_ID=$BUILD_ID bash run-neutron.sh
    node=$(./ssh.sh dev_ci cat ${BUILD_ID}.node)
    node_ip=$(echo "$node" | get_node_ip)

    while ! ./ssh-as-jenkins.sh dev_ci $node_ip test -e /opt/stack/new/devstacklog.txt; do
        echo "Waiting for devstack log to be born"
        sleep 5
    done

    echo "*** Devstack LOG ***"
    ./ssh-as-jenkins.sh dev_ci $node_ip cat /opt/stack/new/devstacklog.txt
}


main
