#!/bin/bash

set -eux

TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)

SERVERNAME="${1-`echo 'Please specify as first parameter' && exit 5`}"
NFSPATH="/mate-test"

(
cd $TOP_DIR/jenkins/devstack-xen/
./run-on-devstack.sh "$SERVERNAME" on-domu-configure-xenapinfs.sh "$SERVERNAME" "$NFSPATH"
)
