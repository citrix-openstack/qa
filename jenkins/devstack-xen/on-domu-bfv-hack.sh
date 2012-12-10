#!/bin/bash

set -e
set -x
set -u

function get_old_bfv_exercise 
{
cd $HOME/devstack
# Check out an elder version of boot from volume, and patch it
# git show 96288ba9a9fffa0d45545d091bd9781476503f7c:exercises/boot_from_volume.sh > exercises/boot_from_volume.sh
#wget -qO - "https://raw.github.com/citrix-openstack/devstack/96288ba9a9fffa0d45545d091bd9781476503f7c/exercises/boot_from_volume.sh" > exercises/boot_from_volume.sh
#wget -qO - "https://review.openstack.org/gitweb?p=openstack-dev/devstack.git;a=commitdiff_plain;h=7e6a648670bfaab75dc8c08ad522e611ca32d994" |
#patch exercises/boot_from_volume.sh
wget -qO - "https://raw.github.com/citrix-openstack/devstack/qndbfv/exercises/boot_from_volume.sh" > exercises/boot_from_volume.sh
}


function amend_localrc_for_bfv
{

eval `grep XENAPI_PASSWORD localrc`
eval `grep XENAPI_CONNECTION_URL localrc`

cd $HOME/devstack
cat >> localrc << EOF

# QND BFV
SKIP_EXERCISES=aggregates,bundle,client-args,client-env,euca,floating_ips,quantum-adv-test,sec_groups,swift,volumes,horizon

# CONFIGURE XenAPINFS
CINDER_DRIVER=XenAPINFS
CINDER_XENAPI_CONNECTION_URL=$XENAPI_CONNECTION_URL
CINDER_XENAPI_CONNECTION_USERNAME=root
CINDER_XENAPI_CONNECTION_PASSWORD=$XENAPI_PASSWORD
CINDER_XENAPI_NFS_SERVER=copper.eng.hq.xensource.com
CINDER_XENAPI_NFS_SERVERPATH=/func-volume-test

# use cirros image
DEFAULT_IMAGE_NAME=cirros

# use m1.small (m1.tiny is not enough to launch cirros)
DEFAULT_INSTANCE_TYPE=m1.small

# Don't reclone - otherwise patches are overwritten
RECLONE=no

EOF
}

function restart_devstack
{
cd $HOME
./run.sh
}

function upload_cirros
{
(
set +u
cd $HOME/devstack
. openrc admin
glance image-create --name cirros \
--copy-from=http://copper.eng.hq.xensource.com/images-new/cirros-0.3.0-x86_64-disk.vhd.tgz \
--container-format=ovf --disk-format=vhd
echo "Cirros image uploaded, waiting 10 secs for glance..."
sleep 10
)
}

function pre_cache_cirros_rootfs
{
cd $HOME
wget -qN https://launchpad.net/cirros/trunk/0.3.0/+download/cirros-0.3.0-x86_64-rootfs.img.gz
}

get_old_bfv_exercise
amend_localrc_for_bfv
restart_devstack
upload_cirros
pre_cache_cirros_rootfs
