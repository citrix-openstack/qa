#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME

Create a ceph box

positional arguments:
 XENSERVERNAME     The name of the XenServer
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"

set -x

SLAVE_IP=$(cat $XSLIB/start-slave.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME")

"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" << END_OF_XSCORE_BUILD_SCRIPT
set -eux

sudo apt-get -qy update
sudo apt-get -qy dist-upgrade
sudo apt-get install -qy git

git clone https://github.com/xapi-project/xenserver-core.git xenserver-core

cd xenserver-core
sudo ./configure.sh
./makemake.py > Makefile
sudo make
END_OF_XSCORE_BUILD_SCRIPT
