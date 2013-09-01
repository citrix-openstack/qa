#!/bin/bash
set -eu

REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)
XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDDIR=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)

function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 ISOURL XENSERVER

... TODO

Positional arguments:
  ISOURL    - An url containing the original XenServer iso
  XENSERVER - Target XenServer
  VMNAME    - Name of the VM
  NETNAME   - Network to use
  DEVBOX_IP - IP of devbox
  VH_IP     - IP of the virtual hypervisor
USAGE
exit 1
}

ISOURL=${1-$(print_usage_and_quit)}
XENSERVER=${2-$(print_usage_and_quit)}
VMNAME=${3-$(print_usage_and_quit)}
NETNAME=${4-$(print_usage_and_quit)}
DEVBOX_IP=${5-$(print_usage_and_quit)}
VH_IP=${6-$(print_usage_and_quit)}

function generate_devbox_key() {
"$REMOTELIB/bash.sh" "ubuntu@$DEVBOX_IP" << END_OF_GENERATE_KEY
set -eux
(
[ -e ~/.ssh/id_rsa_devbox ] || ssh-keygen -q -C "devbox" -N "" -f ~/.ssh/id_rsa_devbox
) > /dev/null
cat ~/.ssh/id_rsa_devbox.pub
END_OF_GENERATE_KEY
}

function add_key_to_xenserver() {
    local pubkey

    pubkey="$1"

"$REMOTELIB/bash.sh" "root@$XENSERVER" << END_OF_XENSERVER_SETUP
set -eux

grep "$pubkey" ~/.ssh/authorized_keys || echo "$pubkey" >> ~/.ssh/authorized_keys
END_OF_XENSERVER_SETUP
}

set -x

add_key_to_xenserver "$(generate_devbox_key)"

"$REMOTELIB/bash.sh" "ubuntu@$DEVBOX_IP" << PREPARE_DEVBOX_END
set -eux
sudo apt-get -qy install git p7zip-full genisoimage fakeroot
PREPARE_DEVBOX_END

cat "$BUILDDIR/create-virtual-hypervisor.sh" | "$REMOTELIB/bash.sh" "ubuntu@$DEVBOX_IP" \
    "$ISOURL" \
    "$XENSERVER" \
    "$VMNAME" \
    "$NETNAME" \
    "~/.ssh/id_rsa_devbox" \
    "$VH_IP"
