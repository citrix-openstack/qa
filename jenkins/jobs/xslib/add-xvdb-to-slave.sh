set -eux

VDI="$1"
SLAVENAME="${2:-trusty}"

VM=$(xe vm-list name-label=$SLAVENAME --minimal)

VBD=$(xe vbd-create vm-uuid=$VM vdi-uuid=$VDI device=1)

xe vbd-plug uuid=$VBD
