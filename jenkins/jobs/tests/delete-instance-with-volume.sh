cd /opt/stack/devstack
. openrc admin

set -exu

function extract_id {
    sed -e 's/^| //g' -e 's/ |.*$//g'
}

function sleepwhile {
    while $@
    do
        sleep 1
    done
}

function sleepwhilenot {
    while ! $@
    do
        sleep 1
    done
}

function volume_is_available {
    cinder list | grep $1 | grep available
}

function volume_exists {
    cinder list | grep $1
}

function instance_active {
    nova list | grep $1 | grep ACTIVE
}

function instance_exists {
    nova list | grep $1
}

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
