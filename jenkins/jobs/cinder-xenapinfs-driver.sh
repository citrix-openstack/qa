#!/bin/bash

set -eux

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
TESTLIB=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME NFSSERVER NFSPATH

Run XenAPINFS integration tests

positional arguments:
 SERVERNAME     The name of the XenServer
 NFSSERVER      Server, that has the NFS share
 NFSPATH        The path of the exported nfs server
 SERVERPASS     The password for the XenServer
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
NFSSERVER="${2-$(print_usage_and_die)}"
NFSPATH="${3-$(print_usage_and_die)}"
SERVERPASS="${4-$(print_usage_and_die)}"

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

SLAVE_IP=$(start_slave)
echo "SLAVE IP: $SLAVE_IP"
run_on $SLAVE_IP "$TESTLIB/cinder-xenapinfs-tests.sh" "$SERVERNAME" "$SERVERPASS" "$NFSSERVER" "$NFSPATH"
