set -eux

SLAVENAME="${1:-trusty}"

VM=$(xe vm-list name-label="$SLAVENAME" --minimal)
SLAVE_IP=$(xe vm-param-get uuid=$VM param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p')

echo "$SLAVE_IP"
