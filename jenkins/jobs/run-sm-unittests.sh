#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Run sm unittests on a new slave

positional arguments:
 XENSERVERNAME     The name of the XenServer
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_SM_TESTING
set -eux

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get -qy install git

git clone https://github.com/matelakat/sm --branch CA-110453 sm

sudo bash sm/tools/install_prerequisites.sh

sm/tools/setup_env.sh
sm/tools/run_tests.sh
END_OF_SM_TESTING
