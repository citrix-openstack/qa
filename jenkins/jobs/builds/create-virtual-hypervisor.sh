set -eu

function print_usage_and_quit
{
cat << USAGE >&2
usage: $0 ISOURL XENSERVER VMNAME NETNAME SSHKEY

Install a DHCP enabled virtual hypervisor on XENSERVER with the name VMNAME.
 - one network interface, connected to NETNAME network on XENSERVER.
 - to connect to XENSERVER, SSHKEY will be used
 - the given ssh key could be used later to access the virtual hypervisor

Positional arguments:
  ISOURL    - An url containing the original XenServer iso
  XENSERVER - Target XenServer
  VMNAME    - Name of the VM
  NETNAME   - Network to use
  SSHKEY    - SSH key to use
USAGE
exit 1
}

ISOURL=${1-$(print_usage_and_quit)}
XENSERVER=${2-$(print_usage_and_quit)}
VMNAME=${3-$(print_usage_and_quit)}
NETNAME=${4-$(print_usage_and_quit)}
SSHKEY=${5-$(print_usage_and_quit)}

set -x

eval $(ssh-agent)
ssh-add "$SSHKEY"

TEMPDIR=$(mktemp -d)

XSISOFILE="$TEMPDIR/xs.iso"
CUSTOMXSISO="$TEMPDIR/xscustom.iso"
ANSWERFILE="$TEMPDIR/answerfile"
VHROOT="$TEMPDIR/vh"

function on_xenserver() {
ssh -q \
    -o Batchmode=yes \
    -o UserKnownHostsFile=/dev/null \
    -o StrictHostKeyChecking=no \
    "root@$XENSERVER" bash -s --
}

on_xenserver << EOF
xe vm-uninstall vm="$VMNAME" force=true || true
EOF

git clone git://github.com/matelakat/virtual-hypervisor.git "$VHROOT"

wget -qO "$TEMPDIR/xs.iso" "$ISOURL"

$VHROOT/scripts/generate_answerfile.sh \
    dhcp > "$ANSWERFILE"

$VHROOT/scripts/create_customxs_iso.sh \
    "$XSISOFILE" "$CUSTOMXSISO" "$ANSWERFILE"

# Cache the server's key to known_hosts
ssh-keyscan "$XENSERVER" >> ~/.ssh/known_hosts

$VHROOT/scripts/xs_start_create_vm_with_cdrom.sh \
    "$CUSTOMXSISO" "$XENSERVER" "$NETNAME" "$VMNAME"

vm=$(echo "xe vm-list name-label='$VMNAME' --minimal" | on_xenserver)
mac=$(echo "xe vif-list vm-uuid=$vm params=MAC --minimal" | on_xenserver)
vhip="192.168.32.10"

# Wipe existing config
sudo sed -i /etc/dnsmasq.conf -e "s/.*$vhip.*//g"

# Reserve the IP
sudo tee -a /etc/dnsmasq.conf << EOF
dhcp-host=$mac,$vhip
EOF

# Restart dnsmasq (due to config file changes)
sudo service dnsmasq restart

# Make a record of that IP
echo "$vhip" > ~/.vhip

on_xenserver << EOF
xe vm-start vm="$VMNAME"
EOF

# wait till ssh is up on VH
while ! echo "kk" | nc "$vhip" 22; do
    sleep 1
done

# Install sshpass on local system
sudo apt-get install -qy sshpass

# Store host key
ssh-keyscan "$vhip" >> ~/.ssh/known_hosts

# Setup passwordless ssh
sshpass -p 'somepass' ssh-copy-id -i ~/.ssh/id_rsa_devbox.pub "root@$vhip"

rm -rf "$TEMPDIR"
