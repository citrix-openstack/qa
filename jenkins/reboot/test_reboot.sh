#!/bin/bash

set -eux

nodes=($(xe vm-list --minimal tags:contains=openstack power-state=running | sed "s/,/\n/g"))
numnodes=${#nodes[@]}

for node in ${nodes[@]}
do
    xe vm-reboot uuid=$node
done

for retry in $(seq 1 3)
do
  upnodes=($(xe vm-list --minimal tags:contains=openstack params=networks power-state=running | \
             grep -o "192.168.[0-9]*.[0-9]*"))
  numupnodes=${#upnodes[@]}

  if [ $numupnodes -lt $numnodes ]
  then
    echo "$numupnodes of $numnodes have rebooted."
    sleep 120
  else
    break
  fi
done

if [ $numupnodes -lt $numnodes ]
then
  echo "Failed to reboot all $numnodes -- only $numupnodes rebooted."
  exit 1
else
  echo "All $numnodes rebooted."
fi
