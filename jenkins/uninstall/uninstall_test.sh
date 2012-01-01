#!/bin/sh

set -eux

thisdir=$(dirname "$0")

. "$thisdir/common.sh"

url="$1"

cd "$thisdir"

fetch_vpx_scripts "$url"
clean_host

check_clean()
{
    local objs=$(xe_min $1)
    if [ "$objs" != "" ]
    then
        echo "Failure: Found $2: $objs." >&2
        exit 1
    fi
}

check_clean "vdi-list other-config:os-vpx=true" "System VDIs"
check_clean "vdi-list other-config:os-vpx-data=true" "Data VDIs"
check_clean "vdi-list other-config:os-vpx-extra=true" "Extra VDIs"
check_clean "vdi-list other-config:os-vpx-images=true" "Images VDIs"
check_clean "vm-list other-config:os-vpx=true" "VMs"
check_clean "vm-list other-config:nova=true" "Nova Instances"
check_clean "vdi-list other-config:nova=true" "Glance VDIs"
check_clean "template-list other-config:os-vpx=true" "templates"
