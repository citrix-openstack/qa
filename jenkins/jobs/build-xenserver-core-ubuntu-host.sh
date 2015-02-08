#!/bin/bash

set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 HOSTNAME COMMIT REPO_URL

Build xenserver-core packages

positional arguments:
 HOSTNAME          The name of the Ubuntu host on which we are going to compile
 COMMIT            The commit sha1 to be tested
 REPO_URL          xenserver-core repository location

optional arguments:
 -p           Use parallel make
 -s <URL>     Download sources from <URL>
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
PARALLEL_MAKE=0
DOWNLOAD_SOURCES_URL=""
# Get optional parameters
set +e
while getopts "ps:" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        p)
	    PARALLEL_MAKE=1
            ;;
        s)
            DOWNLOAD_SOURCES_URL="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
    esac
done
set -e

set -x

"$REMOTELIB/bash.sh" "root@$HOSTNAME" << END_OF_XSCORE_BUILD_SCRIPT

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

sudo apt-get update
sudo apt-get install git ocaml-nox

[ -d xenserver-core ] || git clone $REPO_URL xenserver-core
cd xenserver-core
git fetch origin '+refs/pull/*:refs/remotes/origin/pr/*'

git checkout $COMMIT
git log -1 --pretty=format:%H

if [ -n "$DOWNLOAD_SOURCES_URL" ]; then
  cd SOURCES
  set +e
  wget -A gz -m -p -E -k -K -np -nH -nd -nv $DOWNLOAD_SOURCES_URL
  set -e
  cd ..
fi


sudo ./configure.sh
if [ $PARALLEL_MAKE -eq 1 ]; then
  NUM_CORES=\$(grep -c '^processor' /proc/cpuinfo)
else
  NUM_CORES=1
fi
sudo make  -j \$NUM_CORES
END_OF_XSCORE_BUILD_SCRIPT
