#!/bin/bash
set -e

SERVICES="n-cond n-sch n-novnc n-cauth n-cpu"

function usage(){
    echo "Usage: $0 <BASE_DIR> <XS_HOST> [<DEVSTACK_VM>]"
    echo
    echo "Copies local changes to the specific devstack setup (plugins to XS_HOST, nova to DEVSTACK_VM)"
    echo "dom0 Plugins collected from os-xenapi (falling back to Nova)"
    echo ""
    echo "Projects updated: nova (os-xenapi)"
    echo ""
    echo "Processes restarted: $SERVICES"
    echo
    echo "Passwordless authentication needed for both root@XS_HOST and stack@DEVSTACK_VM"
    exit 1
}

BASE_DIR=$1
XS_HOST=$2
DS_VM=${3:-auto}

_SSH_OPTIONS="\
-q \
-o BatchMode=yes \
-o StrictHostKeyChecking=no \
-o UserKnownHostsFile=/dev/null"

if [ -n "$PRIVKEY" ]; then
  _SSH_OPTIONS="$_SSH_OPTIONS -i $PRIVKEY"
fi


[ -e $BASE_DIR/nova/nova ] || ( echo "*** Cannot find $BASE_DIR/nova/nova"; usage)
ssh $_SSH_OPTIONS root@$XS_HOST /bin/true || ( echo "*** Cannot SSH to host"; usage)

set -eu

if [ "$DS_VM" == "auto" ]; then
    ds_networks=`ssh root@$XS_HOST xe vm-list other-config:os-vpx=true params=networks --minimal`
    ds_pub_net=`echo $ds_networks | tr ';' '\n' | grep "0/ip:"`
    DS_VM=`echo $ds_pub_net | cut -d':' -f2 | tr -d '[[:space:]]'`
fi

ssh $_SSH_OPTIONS stack@$DS_VM /bin/true || ( echo "*** Cannot SSH to DSVM"; usage)

SCREEN_NAME="stack"
for service in $SERVICES; do
    echo "*** Stopping $service"
    cmd="screen -S $SCREEN_NAME -p $service -X stuff \"\""
    ssh $_SSH_OPTIONS stack@$DS_VM $cmd || /bin/true
done

NOVA_PLUGIN_DIR=$BASE_DIR/nova/plugins/xenserver/xenapi/etc/xapi.d/plugins/
OS_XENAPI_PLUGIN_DIR=$BASE_DIR/os-xenapi/os_xenapi/dom0/etc/xapi.d/plugins/
if [ -e $OS_XENAPI_PLUGIN_DIR ]; then
    echo "*** Updating plugins on $XS_HOST (from os-xenapi)"
    rsync -arp $OS_XENAPI_PLUGIN_DIR/* -e "ssh $_SSH_OPTIONS" root@$XS_HOST:/etc/xapi.d/plugins
elif [ -e $NOVA_PLUGIN_DIR ]; then
    echo "*** Updating plugins on $XS_HOST (from nova)"
    rsync -arp $NOVA_PLUGIN_DIR/* -e "ssh $_SSH_OPTIONS" root@$XS_HOST:/etc/xapi.d/plugins
else
    echo "*** Cannot find plugins in nova or os-xenapi ($NOVA_PLUGIN_DIR, $OS_XENAPI_PLUGIN_DIR)"
    exit 1
fi
ssh $_SSH_OPTIONS root@$XS_HOST "chmod +x /etc/xapi.d/plugins/*"

echo "*** Updating Nova on $DS_VM"
rsync -arp $BASE_DIR/nova/* -e "ssh $_SSH_OPTIONS" stack@$DS_VM:/opt/stack/nova

if [ -e $BASE_DIR/os-xenapi ]; then
    echo "*** Updating os-xenapi on $DS_VM"
    rsync -arp $BASE_DIR/os-xenapi/* -e "ssh $_SSH_OPTIONS" stack@$DS_VM:/opt/stack/os-xenapi
fi

SCREEN_NAME="stack"
NL=`echo -ne '\015'`
for service in $SERVICES; do
    echo "*** Restarting $service"
    cmd="screen -S $SCREEN_NAME -p $service -X stuff \"!?$service?$NL\""
    ssh $_SSH_OPTIONS stack@$DS_VM $cmd
done

