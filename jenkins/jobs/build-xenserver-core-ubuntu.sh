#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVERNAME SLAVE_PARAM_FILE COMMIT REPO_URL

Build xenserver-core packages

positional arguments:
 XENSERVERNAME     The name of the XenServer
 SLAVE_PARAM_FILE  The slave VM's parameters will be placed to this file
 COMMIT            The commit sha1 to be tested
 REPO_URL          xenserver-core repository location
 UBUNTU_VERSION    raring / trusty
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"
SLAVE_PARAM_FILE="${2-$(print_usage_and_die)}"
COMMIT="${3-$(print_usage_and_die)}"
REPO_URL="${4-$(print_usage_and_die)}"
UBUNTU_VERSION="${5-$(print_usage_and_die)}"

set -x

WORKER=$(cat $XSLIB/get-worker.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME" none $UBUNTU_VERSION $UBUNTU_VERSION)

echo "$WORKER" > $SLAVE_PARAM_FILE

args="MIRROR=http://mirror.pnl.gov/ubuntu"

"$REMOTELIB/bash.sh" $WORKER << END_OF_XSCORE_BUILD_SCRIPT
set -eux

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get install git ocaml-nox

git clone $REPO_URL xenserver-core
cd xenserver-core
git fetch origin '+refs/pull/*:refs/remotes/origin/pr/*'

git checkout $COMMIT
git log -1 --pretty=format:%H

sudo $args ./configure.sh
sudo $args make  -j `grep -c '^processor' /proc/cpuinfo`
END_OF_XSCORE_BUILD_SCRIPT
