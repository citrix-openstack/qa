#!/bin/bash

set -eu

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME GITREPO DDK_ROOT_URL GITBRANCH

Build Nova Supplemental Pack

positional arguments:
 SERVERNAME     The name of the XenServer
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

function start_slave
{
    "$SCRIPTDIR/run-on-xenserver.sh" "$SERVERNAME" "$XSLIB/start-slave.sh"
}

function run_on
{
    THE_IP="$1"
    SCRIPT="$2"
    shift 2

    cat "$SCRIPT" | ssh -q -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$THE_IP" bash -s -- "$@"
}

echo "Spinning up virtual machine"
SLAVE_IP=$(start_slave)
echo "Starting job on $SLAVE_IP"
run_on $SLAVE_IP "$BUILDLIB/builds/devstack-xva/build.sh"
echo "Copying build result to copper"
scp ubuntu@$SLAVEIP:output.xva jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/devstack.xva
