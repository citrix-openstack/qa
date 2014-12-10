#!/bin/bash
set -eux

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh


function finish {
    ./ssh.sh dev_ci BUILD_ID=$BUILD_ID bash kill-node.sh
}


function main() {
    check_out_infra
    enter_infra_osci
    ./scp.sh dev_ci $THIS_DIR/oscilib/utils.sh utils.sh
    ./scp.sh dev_ci $THIS_DIR/oscilib/run-neutron.sh run-neutron.sh
    ./scp.sh dev_ci $THIS_DIR/oscilib/kill-node.sh kill-node.sh
    trap finish EXIT
    ./ssh.sh dev_ci BUILD_ID=$BUILD_ID bash run-neutron.sh
    sleep 1000
}


main
