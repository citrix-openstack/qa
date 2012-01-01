#!/bin/bash

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

master_vpx=$(get_vm_uuid_by_other_config "vpx-test-master=true")
xe_min vm-shutdown uuid=$master_vpx

data_disk_vdi=$(xe_min vbd-list other-config:os-vpx-data=true \
                                vm-uuid=$master_vpx \
                                params=vdi-uuid)
data_disk_vbd=$(xe_min vbd-list other-config:os-vpx-data=true \
                                vm-uuid=$master_vpx)
image_disk_vbd=$(xe_min vbd-list other-config:os-vpx-images=true \
                                 vm-uuid=$master_vpx)

xe vbd-destroy uuid=$data_disk_vbd
if [ "$image_disk_vbd" != "" ]
then
  xe vbd-destroy uuid=$image_disk_vbd
fi

xe_min vm-param-set "other-config:vpx-test-master=false" \
                     uuid=$master_vpx

echo $data_disk_vdi