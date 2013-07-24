#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)

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

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_SM_TEST_PY24
set -eux

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get -qy install git

git clone https://github.com/matelakat/sm --branch CA-110453-fixedup sm

sudo USE_PYTHON24="yes" bash sm/tests/install_prerequisites_for_python_unittests.sh

USE_PYTHON24="yes" sm/tests/setup_env_for_python_unittests.sh
sm/tests/run_python_unittests.sh
END_OF_SM_TEST_PY24

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_SM_TEST_UPSTERAM_PY
set -eux

export DEBIAN_FRONTEND=noninteractive
sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get -qy install git

git clone https://github.com/matelakat/sm --branch CA-110453-fixedup sm

sudo bash sm/tests/install_prerequisites_for_python_unittests.sh

sm/tests/setup_env_for_python_unittests.sh
sm/tests/run_python_unittests.sh
END_OF_SM_TEST_UPSTERAM_PY
