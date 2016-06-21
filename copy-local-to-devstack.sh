#!/bin/bash
set -e

function usage(){
    echo "Usage: $0 <NOVA_DIR> <XS_HOST> <DEVSTACK_VM>"
    echo
    echo "Copies NOVA_DIR to the specific devstack setup (plugins to XS_HOST, nova to DEVSTACK_VM)"
    echo
    echo "Passwordless authentication needed for both root@XS_HOST and stack@DEVSTACK_VM"
    exit 1
}

NOVA_DIR=$1
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


[ -e $NOVA_DIR/nova ] || usage
ssh $_SSH_OPTIONS root@$XS_HOST /bin/true || usage

set -eu

if [ "$DS_VM" == "auto" ]; then
    ds_networks=`ssh root@$XS_HOST xe vm-list other-config:os-vpx=true params=networks --minimal`
    ds_pub_net=`echo $ds_networks | tr ';' '\n' | grep "0/ip:"`
    DS_VM=`echo $ds_pub_net | cut -d':' -f2 | tr -d '[[:space:]]'`
fi

ssh $_SSH_OPTIONS stack@$DS_VM /bin/true || usage

echo "*** Stopping nova-compute"
ssh $_SSH_OPTIONS stack@$DS_VM "killall -s INT nova-compute || /bin/true"

echo "*** Updating plugins on $XS_HOST"
rsync -arp $NOVA_DIR/plugins/xenserver/xenapi/etc/xapi.d/plugins/ -e "ssh $_SSH_OPTIONS" root@$XS_HOST:/etc/xapi.d/plugins

echo "*** Updating Nova on $DS_VM"
rsync -arp $NOVA_DIR/* -e "ssh $_SSH_OPTIONS" stack@$DS_VM:/opt/stack/nova

echo "*** Restarting nova-compute"
command="/usr/local/bin/nova-compute --config-file /etc/nova/nova.conf"
SERVICE_DIR="/opt/stack/status"
SCREEN_NAME="stack"
name=n-cpu
NL=`echo -ne '\015'`
cmd="screen -S $SCREEN_NAME -p $name -X stuff \"$command & echo \$! >$SERVICE_DIR/$SCREEN_NAME/${name}.pid; fg || echo \\\"$name failed to start\\\" | tee \\\"$SERVICE_DIR/$SCREEN_NAME/${name}.failure\\\"$NL\""
ssh $_SSH_OPTIONS stack@$DS_VM $cmd

