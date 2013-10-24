#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)

. "$THISDIR/functions.sh"

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME GITREPO DDK_ROOT_URL GITBRANCH

Build Nova Supplemental Pack

positional arguments:
 SERVERNAME     The name of the XenServer
 GITREPO        The git repository containing nova code
 DDK_ROOT_URL   An Url pointing to a tgz containing ddk rootfs
 GITBRANCH      Branch to check out
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
GITREPO="${2-$(print_usage_and_die)}"
DDK_ROOT_URL="${3-$(print_usage_and_die)}"
GITBRANCH="${4-$(print_usage_and_die)}"

echo "Spinning up virtual machine"
WORKER=$(cat $XSLIB/get-worker.sh | remote_bash "root@$SERVERNAME")
echo "Starting job on $WORKER"
run_bash_script_on "$WORKER" \
    "$BUILDLIB/build-nova-suppack.sh" "$GITREPO" "$DDK_ROOT_URL" "$GITBRANCH"
