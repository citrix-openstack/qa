#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common.sh"

autosite="${AUTOSITE-false}"
if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

password="citrix"
devel="${Devel-false}"
server="${Server-$TEST_XENSERVER}"

if [ "$#" -eq 1 ]
then
  server="$1"
fi

master=$(remote_execute "root@$server" \
                          "$thisdir/utils/get_master_address.sh")
remote_execute "root@$server" "$thisdir/utils/os-vpx-ssh.sh" \
                              "$password" \
                              "$master" \
                              "/usr/local/bin/geppetto/backup-os-vpx-master"

vdisk=$(remote_execute "root@$server" \
                       "$thisdir/master-upgrade/master-shutdown.sh")

template_label="\"OpenStack ${product_version}-${xb_build_number}-upgrade\""
remote_execute "root@$server" \
               "$thisdir/master-upgrade/master-install.sh" "$template_label" \
                                                           "$build_url" \
                                                            $devel \
                                                            $vdisk

echo "Waiting some time for the VPX services to be fully up and running..."
sleep 60

new_master=$(remote_execute "root@$server" \
                            "$thisdir/utils/get_master_address.sh")
remote_execute "root@$server" "$thisdir/utils/os-vpx-ssh.sh" \
                              "$password" \
                              "$new_master" \
                              "/usr/local/bin/geppetto/restore-os-vpx-master"

remote_execute "root@$server" "$thisdir/utils/os-vpx-ssh.sh" \
                              "$password" \
                              "$new_master" \
                              "/usr/bin/os-vpx-healthcheck"