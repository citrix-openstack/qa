#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Build Nova Supplemental Pack

positional arguments:
 SERVERNAME     The name of the XenServer
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

echo "Spinning up virtual machine"
SLAVE_IP=$(cat $XSLIB/start-slave.sh |
    "$REMOTELIB/bash.sh" "root@$SERVERNAME")

echo "Starting job on $SLAVE_IP"
cat "$BUILDLIB/builds/devstack-xva/build.sh" |
    "$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP"

echo "Copying build result to copper"
scp ubuntu@$SLAVE_IP:output.xva \
    jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/devstack.xva
