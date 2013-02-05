#!/bin/bash

set -eux

TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)

SERVERNAME="${1-`echo 'Please specify as first parameter' && exit 5`}"
NFSPATH="/mate-test"

(
cd $TOP_DIR/jenkins/devstack-xen/
./run-on-devstack.sh "$SERVERNAME" on-domu-stop-update-restart-cinder.sh
./run-on-devstack.sh "$SERVERNAME" on-domu-copy-volume-to-glance.sh
) 2>&1 | tee -a mate.log
