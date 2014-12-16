#!/bin/bash
set -eux

THIS_FILE=$(readlink -f)
THIS_DIR=$(dirname $THIS_FILE)


. $THIS_DIR/infralib/functions.sh


function main() {
    check_out_infra
    enter_infra_installer
    ls -la
}


main