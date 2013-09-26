#!/bin/bash
set -eu

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
. "$THISDIR/functions.sh"

function print_usage_and_die() {
    log_error << EOF
usage: $0 xenserver xenserver_password

Build a DevStack XVA

$1
EOF
    exit 1
}

set +u
HOST="$1"
shift || print_usage_and_die "No xenserver specified"
XenServerPassword="$1"
shift || print_usage_and_die "No xenserver_password specified"
set -u


SLAVE_IP=$(run_bash_script_on "root@$HOST" "$THISDIR/xslib/start-slave.sh")

echo "Slave IP address: $SLAVE_IP"

echo "Building Devstack XVA" | log_info
run_bash_script_on "ubuntu@$SLAVE_IP" \
    "$THISDIR/builds/build-devstack-xva-online-stage1.sh" "$HOST" "$XenServerPassword"
run_bash_script_on "ubuntu@$SLAVE_IP" \
    "$THISDIR/builds/build-devstack-xva-online-stage2.sh" "$HOST" "$XenServerPassword"

echo "Building Nova suppack" | log_info
run_bash_script_on "ubuntu@$SLAVE_IP" \
    "$THISDIR/builds/build-nova-suppack.sh" "https://github.com/openstack/nova.git" "http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz" "master"

echo "Qualifying Devstack XVA with Nova suppack" | log_info
run_bash_script_on "ubuntu@$SLAVE_IP" \
    "$THISDIR/builds/qualify-devstack-xva.sh" "$HOST" "$XenServerPassword" "~/devstack.xva" "citrix" "~/suppack/novaplugins.iso"
