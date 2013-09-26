#!/bin/bash
set -eux

THISDIR=$(cd $(dirname $(readlink -f "$0")) && pwd)

function run_on
{
    THE_IP="$1"
    SCRIPT="$2"
    shift 2

    TEMPSCRIPT=`mktemp -u`
    scp -o StrictHostKeyChecking=no $SCRIPT ubuntu@$THE_IP:$TEMPSCRIPT
    ssh -o StrictHostKeyChecking=no ubuntu@$THE_IP "chmod 755 $TEMPSCRIPT && ($TEMPSCRIPT $@) && rm $TEMPSCRIPT"
}

SLAVE_IP=$("jenkins/devstack-xen/run-on-xenserver.sh" "$HOST" "jenkins/jobs/xslib/start-slave.sh")

echo "Building Devstack XVA"
run_on "$SLAVE_IP" "$THISDIR/builds/build-devstack-xva-online-stage1.sh" "$HOST" "$XenServerPassword"
run_on "$SLAVE_IP" "$THISDIR/builds/build-devstack-xva-online-stage2.sh" "$HOST" "$XenServerPassword"

echo "Building Nova suppack"
run_on "$SLAVE_IP" "$THISDIR/builds/build-nova-suppack.sh" "https://github.com/openstack/nova.git" "http://copper.eng.hq.xensource.com/builds/ddk-xs6_2.tgz" "master"

echo "Qualifying Devstack XVA with Nova suppack"
run_on "$SLAVE_IP" "$THISDIR/builds/qualify-devstack-xva.sh" "$HOST" "$XenServerPassword" "~/devstack.xva" "citrix" "~/suppack/novaplugins.iso"
