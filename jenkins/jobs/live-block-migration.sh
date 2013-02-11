#!/bin/bash

set -eu

TESTDIR=$(cd $(dirname $(readlink -f "$0")) && cd tests && pwd)
SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Run live block migration tests on SERVERNAME

positional arguments:
 SERVERNAME     The name of a XenServer, which is running devstack
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

set -exu

function run_tests
{
    "$SCRIPTDIR/run-on-devstack.sh" "$SERVERNAME" "$TESTDIR/live-block-migration-tempest.sh"
}

run_tests
