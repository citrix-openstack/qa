set -eux

VDI="$1"
RAM="2GiB"
VM=""

{

UBUTEMPLATE=$(xe template-list name-label="Ubuntu Lucid Lynx 10.04 (64-bit)" --minimal)
VM=$(xe vm-clone uuid=$UBUTEMPLATE new-name-label="Temporary VM")
xe vm-param-set uuid=$VM is-a-template=false
xe vm-param-set uuid=$VM name-description="This is a temporary VM - safe to remove"
xe vm-memory-limits-set static-min=$RAM static-max=$RAM dynamic-min=$RAM dynamic-max=$RAM uuid=$VM
VBD=$(xe vbd-create vm-uuid=$VM vdi-uuid=$VDI device=0 bootable=true)
xe vm-param-set uuid=$VM PV-bootloader=pygrub

NETWORK=$(xe network-list name-label="Pool-wide network associated with eth0" --minimal)
xe vif-create device=0 network-uuid=$NETWORK vm-uuid=$VM

xe vm-start uuid=$VM || true

} >&2

echo "$VM"
