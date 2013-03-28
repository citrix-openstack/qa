set -eux

MACHINE_NAME="$1"

SRCVM=$(xe vm-list name-label="$MACHINE_NAME" --minimal)

VBD=$(xe vbd-list vm-uuid=$SRCVM device=xvdb --minimal)
xe vbd-unplug uuid=$VBD
SYSTEM_VDI=$(xe vbd-param-get uuid=$VBD param-name=vdi-uuid)
xe vbd-destroy uuid=$VBD
echo "$SYSTEM_VDI"
