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
 HOSTNAME     The name of the CentOS host on which we are going to compile
 COMMIT       The commit to use
 REPO_URL     xenserver-core repository location

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


"$REMOTELIB/bash.sh" "root@$HOSTNAME" << END_OF_XSCORE_BUILD_SCRIPT
set -eux

# Need to update nss to install epel now (they disabled SSLv3)
yum update -y nss\\*

# Install epel so we can get mock
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm
set +e
rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm
RET=\$?
if [ \$RET -ne 0 -a \$RET -ne 2 ]; then
  exit \$RET
fi
set -e

yum install -y mock redhat-lsb-core

getent passwd mock || useradd -g mock -d /home/mock -s /bin/bash -p \$(echo mock | openssl passwd -1 -stdin) mock

# Allow mock to sudo
cat >> /etc/sudoers << EOF_SUDOERS
mock    ALL=(ALL)       NOPASSWD:ALL
EOF_SUDOERS

# Ensure we can sudo without a TTY
sed -i -e 's/Defaults    requiretty/#Defaults    requiretty/' /etc/sudoers

if [ $PARALLEL_MAKE -eq 1 ]; then
  NUM_CORES=\$(grep -c '^processor' /proc/cpuinfo)
else
  NUM_CORES=1
fi

# The rest of the script needs to run as the mock user
cat > /home/mock/build.sh << EOF_BUILD_SCRIPT
cd ~
[ -d xenserver-core ] || git clone $REPO_URL xenserver-core
cd xenserver-core
git fetch origin '+refs/pull/*:refs/remotes/origin/pr/*'

git checkout $COMMIT
git log -1 --pretty=format:%H

if [ -n "$DOWNLOAD_SOURCES_URL" ]; then
  cd SOURCES
  wget -A gz -m -p -E -k -K -np -nH -nd -nv $DOWNLOAD_SOURCES_URL
  cd ..
fi

./configure.sh
make -j \$NUM_CORES
RET=\\\$?
if [ \\\$RET -ne 0 ]; then
  tail -n 250 RPMS/*/build.log
  exit \\\$RET
fi
EOF_BUILD_SCRIPT
su - mock -c "bash -eux /home/mock/build.sh"

END_OF_XSCORE_BUILD_SCRIPT
