#!/bin/bash
set -eux

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)
. "$THISDIR/functions.sh"

SLAVE_IP=$(run_bash_script_on "root@$HOST" "$THISDIR/xslib/start-slave.sh")

echo "Building Devstack XVA"
run_bash_script_on "ubuntu@$SLAVE_IP" "$THISDIR/builds/build-devstack-xva-online-stage1.sh" "$HOST" "$XenServerPassword"
run_bash_script_on "ubuntu@$SLAVE_IP" "$THISDIR/builds/build-devstack-xva-online-stage2.sh" "$HOST" "$XenServerPassword"

echo "Building Nova suppack"
run_bash_script_on "ubuntu@$SLAVE_IP" "$THISDIR/builds/build-nova-suppack.sh" "https://github.com/openstack/nova.git" "http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz" "master"

echo "Qualifying Devstack XVA with Nova suppack"
run_bash_script_on "ubuntu@$SLAVE_IP" "$THISDIR/builds/qualify-devstack-xva.sh" "$HOST" "$XenServerPassword" "~/devstack.xva" "citrix" "~/suppack/novaplugins.iso"
