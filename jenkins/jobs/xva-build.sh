#!/bin/bash
set -eu

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
. "$THISDIR/functions.sh"

function print_usage_and_die() {
    log_error << EOF
usage: $0 xenserver xenserver_password setupscript_url devstack_tgz_url nova_repo nova_branch

Build a DevStack XVA

$1
EOF
    exit 1
}

function parse_parameters() {
    set +u
    HOST="$1"
    shift || print_usage_and_die "No xenserver specified"
    XenServerPassword="$1"
    shift || print_usage_and_die "No xenserver_password specified"
    SETUPSCRIPT_URL="$1"
    shift || print_usage_and_die "No setupscript url specified"
    DEVSTACK_TGZ_URL="$1"
    shift || print_usage_and_die "No devstack tgz url specified"
    NOVA_REPO="$1"
    shift || print_usage_and_die "No nova repo specified"
    NOVA_BRANCH="$1"
    shift || print_usage_and_die "No nova branch specified"
    set -u
}

parse_parameters $@


WORKER=$(run_bash_script_on "root@$HOST" "$THISDIR/xslib/get-worker.sh")

echo "Worker: $WORKER"

echo "Building Devstack XVA" | log_info
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-devstack-xva-online-stage1.sh" "$HOST" "$XenServerPassword" "$SETUPSCRIPT_URL" "$DEVSTACK_TGZ_URL"
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-devstack-xva-online-stage2.sh" "$HOST" "$XenServerPassword"

echo "Building Nova suppack" | log_info
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-nova-suppack.sh" "$NOVA_REPO" "http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz" "$NOVA_BRANCH"

echo "Qualifying Devstack XVA with Nova suppack" | log_info
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/qualify-devstack-xva.sh" "$HOST" "$XenServerPassword" "~/devstack.xva" "citrix" "~/suppack/novaplugins.iso"
