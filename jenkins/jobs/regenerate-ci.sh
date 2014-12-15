#!/bin/bash
set -eux


THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh

check_out_infra
enter_infra_installer

./rebuild.sh install_with_gateway
