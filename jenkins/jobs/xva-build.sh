#!/bin/bash
set -eux

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
. "$THISDIR/functions.sh"

function print_usage_and_die() {
    log_error << EOF
usage: $0 xenserver xenserver_password setupscript_url nova_repo nova_branch jeos_url worker_jeos_password

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
    NOVA_REPO="$1"
    shift || print_usage_and_die "No nova repo specified"
    NOVA_BRANCH="$1"
    shift || print_usage_and_die "No nova branch specified"
    JEOS_URL="$1"
    shift || print_usage_and_die "No jeos url specified"
    WORKER_JEOS_PASSWORD="$1"
    shift || print_usage_and_die "No jeos password specified"
    set -u
}

parse_parameters $@


sshpass -p $XenServerPassword ssh-copy-id root@$HOST
WORKER=$(run_bash_script_on "root@$HOST" "$THISDIR/xslib/get-worker.sh")
sshpass -p $WORKER_JEOS_PASSWORD ssh-copy-id $WORKER

echo "Worker: $WORKER"

echo "Building Devstack XVA" | log_info
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-devstack-xva-online-stage1.sh" "$HOST" "$XenServerPassword" "$SETUPSCRIPT_URL" -j "$JEOS_URL"

# Copy ID to devstack domu
DEVSTACK_IP=$(ssh -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$HOST xe vm-list name-label=DevStackOSDomU params=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
sshpass -p citrix ssh-copy-id stack@$DEVSTACK_IP
sshpass -p citrix ssh-copy-id root@$DEVSTACK_IP

# Finally let dom0 log into the worker (dom0 is already set up to be able to log in to itself)
ssh root@$HOST cat /root/.ssh/authorized_keys | ssh $WORKER tee -a /root/.ssh/authorized_keys

run_bash_script_on "root@$HOST" \
    "$THISDIR/builds/build-devstack-xva-online-stage2.sh" "$WORKER"
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-devstack-xva-online-stage3.sh"

echo "Building Nova suppack" | log_info
run_bash_script_on "$WORKER" \
    "$THISDIR/builds/build-nova-suppack.sh" "$NOVA_REPO" "http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz" "$NOVA_BRANCH"
