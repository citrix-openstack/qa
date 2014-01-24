#!/bin/bash

set -eux

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 HOSTNAME SLAVE_PARAM_FILE COMMIT REPO_URL

Build xenserver-core packages

positional arguments:
 HOSTNAME     The name of the host (either Ubuntu host or XenServer)
 COMMIT       The commit sha1 to be tested
 REPO_URL     xenserver-core repository location

optional arguments:
 -s                   Specifies we want to use a slave VM on HOSTNAMEs XenServer
 -f SLAVE_PARAM_FILE  Slave parameters will be placed to this file
EOF
exit 1
}

HOSTNAME="${1-$(print_usage_and_die)}"
shift
COMMIT="${1-$(print_usage_and_die)}"
shift
REPO_URL="${1-$(print_usage_and_die)}"
shift

# Number of options passed to this script
REMAINING_OPTIONS="$#"
USE_SLAVE="false"
# Get optional parameters
set +e
while getopts "sf:u:" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        s)
            USE_SLAVE="true"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        f)
            SLAVE_PARAM_FILE="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
    esac
done
set -e

# Make sure that all options processed
if [ "0" != "$REMAINING_OPTIONS" ]; then
    print_usage_and_die "ERROR: some arguments were not recognised!"
fi

if [ "$USE_SLAVE" == "true" ]; then
    WORKER=$(cat $XSLIB/get-worker.sh | "$REMOTELIB/bash.sh" "root@$HOSTNAME" none raring raring)

    if [ -n "$SLAVE_PARAM_FILE" ]; then
	echo "$WORKER" > $SLAVE_PARAM_FILE
    fi
else
    WORKER="ubuntu@$HOSTNAME"
fi

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
git checkout $COMMIT
git log -1 --pretty=format:%H

sed -ie 's,http://gb.archive.ubuntu.com/ubuntu/,http://mirror.anl.gov/pub/ubuntu/,g' scripts/deb/pbuilderrc.in

cat >> pbuilderrc.in << EOF
export http_proxy=http://gold.eng.hq.xensource.com:8000
EOF

sudo ./configure.sh
sudo make
END_OF_XSCORE_BUILD_SCRIPT
