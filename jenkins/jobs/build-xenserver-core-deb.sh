#!/bin/bash

set -eux

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 HOSTNAME COMMIT REPO_URL

Build xenserver-core packages

positional arguments:
 HOSTNAME     The name of the host (either Ubuntu host or XenServer)
 COMMIT       The commit sha1 to be tested
 REPO_URL     xenserver-core repository location

optional arguments:
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
# Get optional parameters
set +e
while getopts "f:" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
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

WORKER="root@$HOSTNAME"
DIST="jessie"
args="DIST=$DIST"
args="$args MIRROR=http://ftp.us.debian.org/debian/"
args="$args APT_REPOS='|deb @MIRROR@ @DIST@ contrib |deb @MIRROR@ @DIST@-backports main '"

"$REMOTELIB/bash.sh" $WORKER << END_OF_XSCORE_BUILD_SCRIPT
set -eux

sudo tee /etc/apt/apt.conf.d/90-assume-yes << APT_ASSUME_YES
APT::Get::Assume-Yes "true";
APT::Get::force-yes "true";
APT_ASSUME_YES

sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get install git ocaml-nox lsb-release

[ -e xenserver-core ] || git clone $REPO_URL xenserver-core
cd xenserver-core
git remote update
git reset --hard HEAD
git clean -f
git checkout $COMMIT
git log -1 --pretty=format:%H

cat >> scripts/deb/templates/pbuilderrc << EOF
#export http_proxy=http://gold.eng.hq.xensource.com:8000
DEBOOTSTRAPOPTS=--no-check-gpg
EOF

cat >> scripts/deb/templates/D04backports << EOF
echo "I: Pinning repositories"
tee /etc/apt/preferences.d/50backports << APT_PIN_BACKPORTS
Package: *
Pin: release a=$DIST-backports
Pin-Priority: 600
APT_PIN_BACKPORTS
tee /etc/apt/preferences.d/60local << APT_PIN_LOCAL
Package: *
Pin: origin ""
Pin-Priority: 600
APT_PIN_LOCAL
EOF
cp scripts/deb/templates/D04backports scripts/deb/templates/F04backports

sudo $args ./configure.sh
sudo make
END_OF_XSCORE_BUILD_SCRIPT
