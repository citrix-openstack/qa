#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME GITREPO GITBRANCH DDK_ROOT_URL

Build Quantum-Agent RPM

positional arguments:
 SERVERNAME     The name of the XenServer
 GITREPO        The git repository containing quantum code
 GITBRANCH      The branch of the git repository to use
 DDK_ROOT_URL   An Url pointing to a tgz containing ddk rootfs

An example run:

./build-quantum-rpm.sh xenserver \
    https://github.com/openstack/quantum \
    http://copper.eng.hq.xensource.com/builds/ddk.tgz

EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
GITREPO="${2-$(print_usage_and_die)}"
GITBRANCH="${3-$(print_usage_and_die)}"
DDK_ROOT_URL="${4-$(print_usage_and_die)}"


SLAVE_IP=$(cat "$XSLIB/start-slave.sh" | $REMOTELIB/bash.sh "root@$SERVERNAME")
echo "Starting job on $SLAVE_IP"

cat "$BUILDLIB/build-quantum-rpm.sh" | 
    $REMOTELIB/bash.sh "ubuntu@$SLAVE_IP" "$GITREPO" "$GITBRANCH" "$DDK_ROOT_URL"
