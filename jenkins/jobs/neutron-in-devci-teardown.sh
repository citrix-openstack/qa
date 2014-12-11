#!/bin/bash
set -eux

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh

enter_infra_osci
./ssh.sh dev_ci BUILD_ID=$BUILD_ID bash kill-node.sh

