#!/bin/bash

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

expected_bridge="$1"
expected_bridge=$(get_network_bridge "$expected_bridge")

if [ "$expected_bridge" == "" ]
then
    echo "Error: unable to locate (test) public network as specified by " \
         "jenkins/sites file. Ensure that the staging network exists." >&2
    exit 1
fi

# find the vm we just launched, this assumes only that ONE vm is launched
i=0
tries=30
while [ $i -lt $tries ]
do
    instance_vm_name=$(xe_min vm-list params=name-label | grep instance | \
                                       sed 's/.*\(instance-[0-9a-f]*\).*/\1/')
    if [ "$instance_vm_name" != "" ]
    then
        network=$(xe_min vm-vif-list \
                         vm="$instance_vm_name" \
                         params=network-uuid)
        [ "$network" != "" ] && break
    fi
    sleep 15
    let i=i+1
done
if [ $i -eq $tries ]
then
    echo "No instance found. Exit with error!"
    exit 1
fi

bridge=$(xe_min network-param-get param-name=bridge uuid="$network")
echo -n "Test bridge on guest instances starts with the one specified..."
if [[ "$bridge" != "$expected_bridge"* ]]
then
  echo "Bridge ($bridge), != ($expected_bridge). Bailing!"
  exit 1
fi
echo "Pass."
