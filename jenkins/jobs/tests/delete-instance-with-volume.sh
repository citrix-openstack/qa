cd /opt/stack/devstack
. openrc admin

set -exu

cinder create 1 --display-name=tstvol
sleepwhilenot volume_is_available tstvol

VOLID=$(cinder list | grep tstvol | extract_id)
IMAGEID=$(glance image-list | grep ami | extract_id)


nova boot --flavor m1.tiny --image $IMAGEID --block-device-mapping /dev/sdb=$VOLID::: tstinst
sleepwhilenot instance_active tstinst
INSTANCEID=$(nova list | grep tstinst | extract_id)

nova delete $INSTANCEID
sleepwhile instance_exists tstvol

sleepwhilenot volume_is_available tstvol

cinder delete $VOLID
sleepwhile volume_exists tstvol
