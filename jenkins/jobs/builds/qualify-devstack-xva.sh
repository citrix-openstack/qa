#!/bin/bash

set -eux

XENSERVERHOST=$1
XENSERVERPASSWORD=$2
DEVSTACKXVA=$3
DEVSTACKPASSWORD=$4
NOVAPLUGINSISO=$5

# Prepare slave requirements
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install xcp-xe stunnel sshpass

# Install the supplemental pack
scp $NOVAPLUGINSISO root@"$XENSERVERHOST":~/novaplugins.iso
ssh root@"$XENSERVERHOST" "echo y | xe-install-supplemental-pack ~/novaplugins.iso"
ssh root@"$XENSERVERHOST" "rm -f ~/novaplugins.iso"

# Install the Devstack VM
OLDDEVSTACKVM=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-list name-label="DevStackOSDomU" --minimal) || true
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-shutdown uuid=$OLDDEVSTACKVM || true
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-destroy uuid=$OLDDEVSTACKVM || true
VM=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-import filename=$DEVSTACKXVA)
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-start uuid=$VM
DEVSTACKVMIP=""
IPTRY=0
while [ -z $DEVSTACKVMIP ];
do
    ((IPTRY=IPTRY+1))
    if [ $IPTRY -ge 30 ]; then
        echo "Failed to get DEVSTACKVMIP"
        exit 1
    fi
    DEVSTACKVMIP=$(xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-param-get uuid=$VM param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')
    sleep 1
done

# Wait for stack.sh to finish
STACKTRY=0
while [ "`sshpass -p $DEVSTACKPASSWORD ssh -o StrictHostKeyChecking=no root@"$DEVSTACKVMIP" "ps axf | grep stack.sh | wc -l"`" != "0" ];
do
    ((STACKTRY=STACKTRY+1))
    if [ $STACKTRY -ge 600 ]; then
	echo "Failed to finish stack.sh within 10 minutes."
	exit 1
    fi
    sleep 1
done

# Run exercise.sh
EXERCISEOUTPUT=`sshpass -p $DEVSTACKPASSWORD ssh -o StrictHostKeyChecking=no root@"$DEVSTACKVMIP" "su stack /opt/stack/devstack/exercise.sh"` || true

# Tidy and act based on the exercise result
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-shutdown uuid=$VM
xe -s $XENSERVERHOST -u root -pw $XENSERVERPASSWORD vm-destroy uuid=$VM

# Return value based on Exercise result
if [ "`echo -e "$EXERCISEOUTPUT" | grep -o "FAILED " | wc -l`" != "0" ]; then
    echo "Exercise failed"
    exit 1
else
    echo "Exercise succeeded"
    exit 0
fi
