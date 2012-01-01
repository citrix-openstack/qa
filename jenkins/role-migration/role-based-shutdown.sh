#!/bin/bash

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

vpx=$(get_vm_uuid_by_role "$1")
xe_min vm-shutdown uuid=$vpx

                        
