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

optional arguments:
 -p           Use parallel make
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"
shift
SLAVE_PARAM_FILE="${1-$(print_usage_and_die)}"
shift
COMMIT="${1-$(print_usage_and_die)}"
shift
REPO_URL="${1-$(print_usage_and_die)}"
shift
UBUNTU_VERSION="${1-$(print_usage_and_die)}"
shift

# Number of options passed to this script
REMAINING_OPTIONS="$#"
PARALLEL_MAKE=0
# Get optional parameters
set +e
while getopts "p" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        p)
	    PARALLEL_MAKE=1
            ;;
    esac
done
set -e

set -x

WORKER=$(cat $XSLIB/get-worker.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME" none $UBUNTU_VERSION $UBUNTU_VERSION)

echo "$WORKER" > $SLAVE_PARAM_FILE

args="MIRROR=http://mirror.pnl.gov/ubuntu"

# Wait for SSH
while [ "`ssh -A -o BatchMode=yes $WORKER echo 1 `" != "1" ]; do
    echo "Waiting for SSH to come up..."
    sleep 30
done

"$REMOTELIB/bash.sh" $WORKER << END_OF_XSCORE_BUILD_SCRIPT
set -eux

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

sudo apt-get update
sudo apt-get install git ocaml-nox

git clone $REPO_URL xenserver-core
cd xenserver-core
git fetch origin '+refs/pull/*:refs/remotes/origin/pr/*'

git checkout $COMMIT
git log -1 --pretty=format:%H

sudo $args ./configure.sh
if [ $PARALLEL_MAKE -eq 1 ]; then
  NUM_CORES=\$(grep -c '^processor' /proc/cpuinfo)
else
  NUM_CORES=1
fi
sudo $args make  -j \$NUM_CORES
END_OF_XSCORE_BUILD_SCRIPT
