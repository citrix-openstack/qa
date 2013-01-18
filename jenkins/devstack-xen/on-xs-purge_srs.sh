#!/bin/bash

set -x

function label_is_fine
{
case "$1" in
  "Removable storage") true ;;
  "DVD drives" ) true ;;
  "XenServer Tools" ) true ;;
  "Removable storage" ) true ;;
  "Local storage" ) true ;;
  *) false
   ;;
esac
}

function remove_sr
{
  pbd=`xe pbd-list sr-uuid=$1 --minimal`
  xe pbd-unplug uuid=$pbd
  xe pbd-destroy uuid=$pbd
  xe sr-destroy uuid=$1
  xe sr-forget uuid=$1
}

for uuid in `xe sr-list --minimal | sed -e "s/,/ /g"`;
do
label=`xe sr-param-get uuid=$uuid param-name=name-label --minimal`
label_is_fine "$label" || remove_sr "$uuid"
done
