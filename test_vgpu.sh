#!/bin/bash

# This script is used to install an openstack environment to check vgpu
# features. It should be called on a compute node which located on a xenserver
# host with GPU cards.
#
# Example:
# $0 $zuul_ref $zuul_changes $keep_env_flag
#
# zuul_ref: the commit ref from ZUUL
# zuul_changes: related branch changes
# keep_env_flag: if this flag set to "true", will don't clean the environment
# after test finished.

set -ex
refspec="$1"
ZUUL_CHANGES="$2"
keep_env=${3:-false}

if [ -z "$ZUUL_CHANGES" -o -z "$refspec" -o -z "$ZUUL_CHANGE" ]; then
    echo "ZUUL parameters needed"
    exit 1
fi

FETCH_URL=${FETCH_URL:-"http://10.71.212.50/p/"}
ROOT_DIR=/opt/stack/
DEVSTACK_PATH=/opt/stack/devstack
TEST_BRANCH=$ZUUL_CHANGE
DEST=${DEST:-"/opt/stack/openstack"}
TEMPEST_DIR=$DEST/tempest
NOVA_CONF=/etc/nova/nova.conf
IMAGE_NAME=${IMAGE_NAME:-"cirros-0.3.5-x86_64-disk"}
VM_NAME=${VM_NAME:-"testVM"}
JOURNAL_DIR=/var/log/journal
VGPU_TEST_LOG_DIR=${VGPU_TEST_LOG_DIR:-"/opt/stack/workspace/test_vgpu/logs"}
TMP_LOG_DIR=/tmp/openstack


SLEEP_TIME_GAP=3
SLEEP_MAX_TRIES=100


echo "###################Test VGPU Begin#####################"

on_exit()
{
    # Post proccess
    # Save logs
    set -x
    echo "###################Exit#####################"
    echo "###################Save logs#####################"
    rm -rf $TMP_LOG_DIR
    mkdir -p $TMP_LOG_DIR
    services=$(ls /etc/systemd/system | grep devstack@)
    for service in $services;
    do
        sudo journalctl --unit $service > $TMP_LOG_DIR/$service".log";
    done
    cp $TMP_LOG_DIR/* $VGPU_TEST_LOG_DIR/
    echo "###################Clean environment if requested#####################"
    if [ $keep_env != "true" ]; then
        pushd $DEVSTACK_PATH/
        nova delete $VM_NAME
        ./clean.sh
        popd
    fi
    set +x
}

trap on_exit EXIT

error_log="VGPU test failed with the following errors: "
# Set up internal variables
_SSH_OPTIONS="\
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i /opt/stack/.ssh/id_rsa"

DOM0_IP=$(grep XENAPI_CONNECTION_URL ${DEVSTACK_PATH}/local.conf | cut -d'=' -f2 | sed 's/[^0-9,.]*//g')

echo "Dom0 IP is: $DOM0_IP"

function on_domzero() {
    ssh $_SSH_OPTIONS "root@$DOM0_IP" bash -s --
}

pushd $DEVSTACK_PATH/

./clean.sh
git checkout master
git pull --ff origin master

popd

if grep "DEST=" ${DEVSTACK_PATH}/local.conf; then
    dest=$(grep "DEST=" ${DEVSTACK_PATH}/local.conf | cut -d= -f2)
    if [ $dest != ${DEVSTACK_PATH} ]; then
        sed -i '/DEST=*/d' ${DEVSTACK_PATH}/local.conf
    fi
fi
if ! grep "DEST=" ${DEVSTACK_PATH}/local.conf; then
    sed -i '/[[local|localrc]]/a DEST=/opt/stack/openstack' ${DEVSTACK_PATH}/local.conf
fi

echo "###################Update openstack repositories#####################"
PROJECT_LIST=$(echo $ZUUL_CHANGES | tr '^' '\n' | cut -d: -f1 | cut -d/ -f2 | sort | uniq)

pushd ${DEST}
for dir in ${DEST}/*
do
    if [ -d "${dir}" ] ; then
        echo "check ${dir}"
        pushd ${dir}
        if [ -d .git ]; then
            echo "update repository ${dir}"
            git checkout master
            if ! git diff-index --quiet HEAD --; then
                git checkout *
            fi
            git pull --ff origin master

            pkg_flag=${dir##*/}
            echo $pkg_flag
            if [[ " ${PROJECT_LIST[@]} " =~ " ${pkg_flag} " ]]; then
                echo "Fetching change for repository ${dir}"
                if git branch | grep -w $TEST_BRANCH; then
                    echo "delete the old temp branch"
                    git branch -D $TEST_BRANCH
                fi
                git checkout master -B $TEST_BRANCH
                git fetch ${FETCH_URL}/openstack/${pkg_flag} $refspec
                git merge FETCH_HEAD -m "temp branch for vgpu patches merge"
            fi
        fi;
        popd
    fi
done

popd

echo "###################Get VGPU type from the host#####################"
first_vgpu_type=$(on_domzero << END_OF_REQ_VGPU_TYPE
vgpu_type_list=\$(xe vgpu-type-list --minimal)
vgpu_type_list=\${vgpu_type_list//,/ }
for id in \$vgpu_type_list
do
    name=\$(xe vgpu-type-param-get uuid=\$id param-name="model-name")
    if [ "\$name" != "passthrough" ]
    then
        echo \$name
        exit
    fi
done
END_OF_REQ_VGPU_TYPE
)

echo "###################Devstack start stack#####################"
pushd $DEVSTACK_PATH/
if ! grep "enabled_vgpu_types=" ${DEVSTACK_PATH}/local.conf; then
    echo "[devices]" >> ${DEVSTACK_PATH}/local.conf
    echo "enabled_vgpu_types = $first_vgpu_type" >> ${DEVSTACK_PATH}/local.conf
fi
sudo find $JOURNAL_DIR -name "*.journal" -exec rm {} \;
sudo systemctl restart systemd-journald
./stack.sh
popd

pushd $TEMPEST_DIR
# TODO: run vgpu tempest

echo "###################Create test VM#####################"
source $DEVSTACK_PATH/openrc admin demo
# Add vgpu resource to falvor 1
nova flavor-key 1 set resources:VGPU=1

# Change image type to hvm because vgpu only support hvm image
image_id=$(glance image-list | grep "$IMAGE_NAME" | awk '{print $2}')
glance image-update  --property vm_mode=hvm $image_id

prv_net=$(openstack network list | grep "private" | awk '{print $2}')
nova boot --image $IMAGE_NAME --flavor 1 --nic net-id=$prv_net $VM_NAME

nova_vm_id=$(nova show $VM_NAME | grep -w 'id' | awk '{print $4}')
count=0
while :
do
    echo "Waitting to VM active"
    sleep $SLEEP_TIME_GAP
    count=$((count + 1))
    vm_state=$(nova show $VM_NAME | grep -w 'status' | awk '{print $4}')
    if [ $vm_state = "ERROR" ]; then
        error_log=$error_log"\n\tVM create failed"
        break
    elif [ $vm_state = "ACTIVE" ]; then
        break
    elif [ $count -gt $SLEEP_MAX_TRIES ]; then
        error_log=$error_log"\n\tVM can not reach active status"
        break
    fi
done

echo "###################Check VGPU create status#####################"
if [ $vm_state = "ACTIVE" ]; then
result=$(on_domzero <<END_OF_VGPU_CONFIRM
vgpu_list=\$(xe vgpu-list --minimal)
vgpu_list=\${vgpu_list//,/ }
for vgpu_id in \$vgpu_list
do
    ret=\$(xe vgpu-param-list uuid=\$vgpu_id | grep $nova_vm_id)
    echo \$ret
done
END_OF_VGPU_CONFIRM
)
fi

if [ -n "$result" ]; then
    echo "VGPU create success"
else
    error_log=$error_log"\n\tVGPU create failed"
    echo $error_log
fi

set +ex
