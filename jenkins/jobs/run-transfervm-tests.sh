#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Run transfervm build on a new slave

positional arguments:
 XENSERVERNAME     The name of the XenServer
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_TVM_TESTS
set -eux

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get -qy install git make

git clone https://github.com/matelakat/transfervm transfervm
END_OF_TVM_TESTS

echo "$SLAVE_IP"
