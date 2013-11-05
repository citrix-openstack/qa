#!/bin/bash

set -eux

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 HOSTNAME COMMIT

Build xenserver-core packages

positional arguments:
 HOSTNAME     The name of the CentOS host on which we are going to compile
 COMMIT       The commit to use
EOF
exit 1
}

HOSTNAME="${1-$(print_usage_and_die)}"
COMMIT="${2-$(print_usage_and_die)}"

"$REMOTELIB/bash.sh" "root@$HOSTNAME" << END_OF_XSCORE_BUILD_SCRIPT
set -eux

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

# The rest of the script needs to run as the mock user
cat >> /home/mock/build.sh << EOF_BUILD_SCRIPT
cd ~
git clone git://github.com/xapi-project/xenserver-core.git
cd xenserver-core
git checkout $COMMIT
git log -1 --pretty=format:%H

./configure.sh
make
EOF_BUILD_SCRIPT
su - mock -c "bash /home/mock/build.sh"

END_OF_XSCORE_BUILD_SCRIPT
