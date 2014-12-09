#!/bin/bash
set -eux

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh


function main() {
    check_out_infra
    enter_infra_osci
    ./scp.sh dev_ci $THIS_DIR/oscilib/utils.sh utils.sh
    ./scp.sh dev_ci $THIS_DIR/oscilib/run-neutron.sh run-neutron.sh
    ./ssh.sh dev_ci run-neutron.sh
}


main
