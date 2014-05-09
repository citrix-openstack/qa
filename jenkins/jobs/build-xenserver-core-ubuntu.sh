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
EOF
exit 1
}

XENSERVERNAME="${1-$(print_usage_and_die)}"
SLAVE_PARAM_FILE="${2-$(print_usage_and_die)}"
COMMIT="${3-$(print_usage_and_die)}"
REPO_URL="${4-$(print_usage_and_die)}"

set -x

WORKER=$(cat $XSLIB/get-worker.sh | "$REMOTELIB/bash.sh" "root@$XENSERVERNAME" none raring raring)

echo "$WORKER" > $SLAVE_PARAM_FILE

args="MIRROR=http://ftp.us.debian.org/debian/"

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

cat >> scripts/deb/templates/pbuilderrc << EOF
export http_proxy=http://gold.eng.hq.xensource.com:8000
EOF

sudo $args ./configure.sh
sudo $args make
END_OF_XSCORE_BUILD_SCRIPT
