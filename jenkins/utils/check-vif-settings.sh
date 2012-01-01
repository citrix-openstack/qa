#!/bin/sh

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

role=$1
device=$2
bridge=$3

vm_uuid=$(get_vm_uuid_by_role "$role")
if [ -n "$vm_uuid" ]
then
  wait_for_vif_up "$vm_uuid" "$device" "$bridge"
else
  echo "Unable to determine vm uuid, bailing!"
  exit 1
fi
