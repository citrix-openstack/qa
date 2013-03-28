set -eux

VDI="$1"

VM=$(xe vm-list name-label=slave --minimal)

VBD=$(xe vbd-create vm-uuid=$VM vdi-uuid=$VDI device=1)

xe vbd-plug uuid=$VBD
