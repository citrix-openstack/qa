#!/bin/bash

set -eux

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)

. "$THISDIR/functions.sh"

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME XENSERVER_DDK_URL

Extract the rootfs of a XenServer ddk

positional arguments:
 SERVERNAME         The name of the XenServer
 XENSERVER_DDK_URL  URL of XenServer DDK
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
XENSERVER_DDK_URL="${2-$(print_usage_and_die)}"
WORKER_JEOS_PASSWORD=${3:-citrix}

echo "Spinning up virtual machine"
WORKER=$(cat $XSLIB/get-worker.sh | remote_bash "root@$SERVERNAME")
sshpass -p $WORKER_JEOS_PASSWORD ssh-copy-id $WORKER

echo "Starting job on $WORKER"
run_bash_script_on $WORKER "$BUILDLIB/create-ddk-rootfs.sh" "$XENSERVER_DDK_URL" "ddk.tgz"
