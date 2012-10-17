#!/bin/bash
set -e 
set -x

##################################################
### Setup localrc
##################################################
(
cd devstack

# backup localrc as localrc.original
[ -e localrc.original ] || cp localrc localrc.original

# create the new localrc
cp localrc.original localrc

cat >> localrc << EOLOC
# Activate SM
EXTRA_OPTS=("agent_version_timeout=1" "volume_driver=nova.volume.xensm.XenSMDriver" "use_local_volumes=False")

# Use nova-volume
disable_service c-api c-sch c-vol cinder
enable_service n-vol

# Don't reclone - otherwise patches are overwritten
RECLONE=no

# Exercise specific settings
# Skip all exercises, except boot from volume
SKIP_EXERCISES=aggregates,bundle,client-args,client-env,euca,floating_ips,quantum-adv-test,sec_groups,swift,volumes
# use cirros image
DEFAULT_IMAGE_NAME=cirros
# use m1.small (m1.tiny is not enough to launch cirros)
DEFAULT_INSTANCE_TYPE=m1.small
EOLOC
)

##################################################
### Apply patches on nova
##################################################
(
cd nova 
git checkout -- .
git checkout master
# As the fixed IP bug is already fixed, we can go with trunk.
# git checkout fb101685cc14ed9b0396ce966e571d3fb457c32f
# Apply John's patch - otherwise n-vol fails to start
wget -qO - "https://review.openstack.org/gitweb?p=openstack/nova.git;a=commitdiff_plain;h=bb0682fc193833a4ef7c27085ea7c1be31139102" | patch -p1
# Apply Renuka's patch
wget -qO - "https://review.openstack.org/gitweb?p=openstack/nova.git;a=commitdiff_plain;h=2b96874dad5000ecfe22df209b6aad9d7f87971c" | patch -p1
)

##################################################
### Start openstack
##################################################
sudo service rabbitmq-server status ||
sudo service rabbitmq-server start &&
echo "Workaround - rabbitmq server was not running - now started"

./run.sh

##################################################
### Activate devstack
##################################################
cd devstack
. openrc admin

##################################################
### Upload image to glance
##################################################
glance image-create --name cirros \
--copy-from=http://copper.eng.hq.xensource.com/images/XS-OpenStack/cirros-0.3.0-x86_64-disk.vhd.tgz \
--container-format=ovf --disk-format=vhd
echo "Cirros image uploaded, waiting 10 secs for glance..."
sleep 10

##################################################
### Create the volume using sm
##################################################
# Stop nova-volume
pkill -HUP -f "/opt/stack/nova/bin/nova-volume"

nova-manage sm flavor_create gold "Not all that glitters"
echo -e "y\n" | nova-manage sm backend_add gold nfs name_label=mybackend server=copper serverpath=/bootfromvolume

# Start nova-volume
NL=`echo -ne '\015'`
screen -S stack -p n-vol -X stuff "cd /opt/stack/nova && /opt/stack/nova/bin/nova-volume$NL"
sleep 2
