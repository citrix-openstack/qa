#!/bin/bash

set -eu

SCRIPTDIR=$(cd $(dirname $(readlink -f "$0")) && cd .. && cd devstack-xen && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME NFSSERVER NFSPATH

Run XenAPINFS-Glance integration related tests.

positional arguments:
 SERVERNAME     The name of the XenServer, which is running devstack
 NFSSERVER      Server, that has the NFS share
 NFSPATH        The path of the exported nfs server
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"
NFSSERVER="${2-$(print_usage_and_die)}"
NFSPATH="${3-$(print_usage_and_die)}"

set -exu

function configure_xenapinfs
{
    (
        cd "$SCRIPTDIR"
        ./run-on-devstack.sh "$SERVERNAME" on-domu-configure-xenapinfs.sh "$NFSSERVER" "$NFSPATH"
    )
}

function test_copy_image_from_glance
{
    (
        cd "$SCRIPTDIR"
        ./run-on-devstack.sh "$SERVERNAME" on-domu-copy-image-from-glance.sh
    )
}

function test_copy_volume_to_glance
{
    (
        cd "$SCRIPTDIR"
        ./run-on-devstack.sh "$SERVERNAME" on-domu-copy-volume-to-glance.sh
    )
}

configure_xenapinfs
test_copy_image_from_glance
test_copy_volume_to_glance
