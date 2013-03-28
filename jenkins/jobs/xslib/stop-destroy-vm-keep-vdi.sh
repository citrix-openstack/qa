set -eux

VM="$1"

xe vm-shutdown force=true uuid=$VM || true

while [ "halted" != "$(xe vm-param-get param-name=power-state uuid=$VM)" ]
do
    sleep 1
done

for VBD in $(xe vbd-list vm-uuid=$VM --minimal | sed -e 's/,/ /g')
do
    xe vbd-destroy uuid=$VBD
done

xe vm-uninstall uuid=$VM force=true
