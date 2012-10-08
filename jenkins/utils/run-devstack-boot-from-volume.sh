#!/bin/bash
set -u
DEVSTACK=$1
sshpass -p citrix rsync -avz --exclude '.git' --exclude '*.swp' . stack@$DEVSTACK:devstack
sshpass -p citrix ssh stack@$DEVSTACK << EOF
set -x

rm -f please_restart_devstack || true

grep -q volume_driver /etc/nova/nova.conf &&
echo "volume_driver already configured" ||
(
cat >> devstack/localrc << EOLOC
EXTRA_OPTS=("agent_version_timeout=1" "volume_driver=nova.volume.xensm.XenSMDriver" "use_local_volumes=False")
EOLOC
echo "localrc modified to include SM in nova.conf" >> please_restart_devstack
)

grep -qe "^disable_service c-api" devstack/localrc &&
echo "cinder already disabled" ||
(
cat >> devstack/localrc << EOLOC
disable_service c-api c-sch c-vol cinder
enable_service n-vol
EOLOC
echo "Cinder disabled, using nova-api instead" >> please_restart_devstack
)

[ -e please_restart_devstack ] &&
(
    echo "Devstack restart required, because:"
    cat please_restart_devstack

    sudo service rabbitmq-server status ||
    sudo service rabbitmq-server start &&
    echo "Rabbitmq server was not running - started" &&
    ./run.sh &&
    rm please_restart_devstack &&
    echo "Devstack restarted successfully."
)

cd devstack
. openrc admin
(
    nova list | grep -q sample_cirros_vm &&
    echo "cirros image already uploaded"
) ||
(
glance image-create --name cirros \
--copy-from=http://copper.eng.hq.xensource.com/images/XS-OpenStack/cirros-0.3.0-x86_64-disk.vhd.tgz \
--container-format=ovf --disk-format=vhd &&
echo "Cirros image uploaded, waiting 10 secs for glance..." &&
sleep 10 &&
nova boot --image=cirros --flavor=m1.small sample_cirros_vm &&
echo "Sample cirros vm launched with small flavor (workaround)"
)

## RUNNING exercise.sh / boot from volume test
grep -qe "^SKIP_EXERCISES=aggregates,bundle,cli" localrc ||
(
cat >> localrc << EOLOC
SKIP_EXERCISES=aggregates,bundle,client-args,client-env,euca,floating_ips,quantum-adv-test,sec_groups,swift,volumes
DEFAULT_IMAGE_NAME=cirros
EOLOC
) && echo "localrc modified (only boot from volume will run)"

nova-manage sm flavor_list | grep -q gold ||
nova-manage sm flavor_create gold "Not all that glitters"

nova-manage sm backend_list | grep -q copper ||
echo -e "y\\n" | nova-manage sm backend_add gold nfs name_label=mybackend server=copper serverpath=/bootfromvolume

./exercise.sh
EOF
