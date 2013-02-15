#!/bin/bash

set -eux

TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)

SERVERNAME="${1-`echo 'Please specify as first parameter' && exit 5`}"

ssh $SERVERNAME << EOF
xe vm-shutdown vm=slave
xe vm-uninstall vm=slave force=true
EOF
