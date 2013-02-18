#!/bin/bash

set -eu

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
SLAVELIB=$(cd $(dirname $(readlink -f "$0")) && cd slavelib && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME NFSSERVER NFSPATH

Run XenAPINFS integration tests

positional arguments:
 SERVERNAME     The name of the XenServer
 NFSSERVER      Server, that has the NFS share
 NFSPATH        The path of the exported nfs server
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
NFSSERVER="${2-$(print_usage_and_die)}"
NFSPATH="${3-$(print_usage_and_die)}"

set -exu

function destroy_slave
{
    "$SCRIPTDIR/run-on-xenserver.sh" "$SERVERNAME" "$XSLIB/destroy-slave.sh"
}

function start_slave
{
    "$SCRIPTDIR/run-on-xenserver.sh" "$SERVERNAME" "$XSLIB/start-slave.sh"
}

function get_slave_ip
{
    "$SCRIPTDIR/run-on-xenserver.sh" "$SERVERNAME" "$XSLIB/get-slave-ip.sh"
}

function run_on
{
    THE_IP="$1"
    SCRIPT="$2"
    shift 2
    cat "$SCRIPT" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$THE_IP" bash -s -- "$@"
}

destroy_slave
start_slave
SLAVE_IP=$(get_slave_ip)
run_on $SLAVE_IP "$SLAVELIB/cinder-xenapinfs-tests.sh"
