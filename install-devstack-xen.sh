#!/bin/bash
set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER XENSERVER_PASS PRIVKEY [-t TEST_TYPE] [-d DEVSTACK_URL] [-f]

A simple script to use devstack to setup an OpenStack, and optionally
run tests on it.

positional arguments:
 XENSERVER        The address of the XenServer
 XENSERVER_PASS   The root password for the XenServer
 PRIVKEY          A passwordless private key to be used for installation.
                  This key will be copied over to the xenserver host, and will
                  be used for migration/resize tasks if multiple XenServers
                  used.

optional arguments:
 TEST_TYPE        Type of the tests to run. One of [none, smoke, full]
                  defaults to none
 DEVSTACK_TGZ     An URL pointing to a tar.gz snapshot of devstack. This
                  defaults to the official devstack repository.

flags:
 -f               Force SR replacement. If your XenServer has an LVM type SR,
                  it will be destroyed and replaced with an ext SR.
                  WARNING: This will destroy your actual default SR !

An example run:

  # Create a passwordless ssh key
  ssh-keygen -t rsa -N "" -f devstack_key.priv

  # Install devstack on XenServer 10.219.10.25
  $0 10.219.10.25 mypassword devstack_key.priv

$@
EOF
exit 1
}

# Defaults for optional arguments
DEVSTACK_TGZ="https://github.com/openstack-dev/devstack/archive/master.tar.gz"
TEST_TYPE="none"
FORCE_SR_REPLACEMENT="false"

# Get Positional arguments
set +u
XENSERVER="$1"
shift || print_usage_and_die "ERROR: XENSERVER not specified!"
XENSERVER_PASS="$1"
shift || print_usage_and_die "ERROR: XENSERVER_PASS not specified!"
PRIVKEY="$1"
shift || print_usage_and_die "ERROR: PRIVKEY not specified!"
set -u

# Number of options passed to this script
REMAINING_OPTIONS="$#"

# Get optional parameters
set +e
while getopts ":t:d:f" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        t)
            TEST_TYPE="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            if ! [ "$TEST_TYPE" = "none" -o "$TEST_TYPE" = "smoke" -o "$TEST_TYPE" = "full" ]; then
                print_usage_and_die "$TEST_TYPE - Invalid value for TEST_TYPE"
            fi
            ;;
        d)
            DEVSTACK_TGZ="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        f)
            FORCE_SR_REPLACEMENT="true"
            ;;
        \?)
            print_usage_and_die "Invalid option -$OPTARG"
            ;;
    esac
done
set -e

# Make sure that all options processed
if [ "0" != "$REMAINING_OPTIONS" ]; then
    print_usage_and_die "ERROR: some arguments were not recognised!"
fi

# Set up internal variables
_SSH_OPTIONS="\
    -q \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i $PRIVKEY"

# Print out summary
cat << EOF
XENSERVER:      $XENSERVER
XENSERVER_PASS: $XENSERVER_PASS
PRIVKEY:        $PRIVKEY
TEST_TYPE:      $TEST_TYPE
DEVSTACK_TGZ:   $DEVSTACK_TGZ

FORCE_SR_REPLACEMENT: $FORCE_SR_REPLACEMENT
EOF

echo -n "Authenticate the key with XenServer..."
tmp_dir="$(mktemp -d)"
ssh-keygen -y -f $PRIVKEY > "$tmp_dir/devstack.pub"
sshpass -p "$XENSERVER_PASS" \
    ssh-copy-id \
        -i "$tmp_dir/devstack.pub" \
        root@$XENSERVER > /dev/null 2>&1
rm -rf "$tmp_dir"
unset tmp_dir
echo "OK"

echo -n "Set up the key as the xenserver's private key..."
scp $_SSH_OPTIONS $PRIVKEY "root@$XENSERVER:.ssh/id_rsa"
echo "OK"

# Helper function
function on_xenserver() {
    ssh $_SSH_OPTIONS "root@$XENSERVER" bash -s --
}

echo -n "Verify that XenServer can log in to itself..."
on_xenserver << END_OF_CHECK_KEY_SETUP
ssh -o StrictHostKeyChecking=no $XENSERVER true
END_OF_CHECK_KEY_SETUP
echo "OK"

echo -n "Verify XenServer has an ext type default SR..."
on_xenserver << END_OF_SR_OPERATIONS
set -eu

# Verify the host is suitable for devstack
defaultSR=\$(xe pool-list params=default-SR minimal=true)
if [ "\$(xe sr-param-get uuid=\$defaultSR param-name=type)" != "ext" ]; then
    if [ "true" == "$FORCE_SR_REPLACEMENT" ]; then
        echo ""
        echo ""
        echo "Trying to replace the default SR with an EXT SR"

        pbd_uuid=\`xe pbd-list sr-uuid=\$defaultSR minimal=true\`
        host_uuid=\`xe pbd-param-get uuid=\$pbd_uuid param-name=host-uuid\`
        use_device=\`xe pbd-param-get uuid=\$pbd_uuid param-name=device-config param-key=device\`

        # Destroy the existing SR
        xe pbd-unplug uuid=\$pbd_uuid
        xe sr-destroy uuid=\$defaultSR

        sr_uuid=\`xe sr-create content-type=user host-uuid=\$host_uuid type=ext device-config:device=\$use_device shared=false name-label="Local storage"\`
        pool_uuid=\`xe pool-list minimal=true\`
        xe pool-param-set default-SR=\$sr_uuid uuid=\$pool_uuid
        xe pool-param-set suspend-image-SR=\$sr_uuid uuid=\$pool_uuid
        xe sr-param-add uuid=\$sr_uuid param-name=other-config i18n-key=local-storage
        exit 0
    fi
    echo ""
    echo ""
    echo "ERROR: The xenserver host must have an EXT3 SR as the default SR"
    echo "Use the -f flag to destroy the current default SR and create a new"
    echo "ext type default SR."
    echo ""
    echo "WARNING: This will destroy your actual default SR !"
    echo ""

    exit 1
fi
END_OF_SR_OPERATIONS
echo "OK"

echo -n "Get the IP address of XenServer..."
XENSERVER_IP=$(on_xenserver << GET_XENSERVER_IP
ifconfig xenbr0 | grep "inet addr" | cut -d ":" -f2 | sed "s/ .*//"
GET_XENSERVER_IP
)
if [ -z "$XENSERVER_IP" ]; then
    echo "Failed to detect the IP address of XenServer"
    exit 1
fi
echo "OK"

TMPDIR=$(echo "mktemp -d" | on_xenserver)

on_xenserver << END_OF_XENSERVER_COMMANDS
set -exu
cd $TMPDIR

wget -qO - "$DEVSTACK_TGZ" |
    tar -xzf -
cd devstack*

cat << LOCALRC_CONTENT_ENDS_HERE > localrc
# Passwords
MYSQL_PASSWORD=citrix
SERVICE_TOKEN=citrix
ADMIN_PASSWORD=citrix
SERVICE_PASSWORD=citrix
RABBIT_PASSWORD=citrix
GUEST_PASSWORD=citrix
XENAPI_PASSWORD="$XENSERVER_PASS"
SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"

# Use xvdb for backing cinder volumes
XEN_XVDB_SIZE_GB=10
VOLUME_BACKING_DEVICE=/dev/xvdb

# Nice short names, so we could export an XVA
VM_BRIDGE_OR_NET_NAME="osvmnet"
PUB_BRIDGE_OR_NET_NAME="ospubnet"
XEN_INT_BRIDGE_OR_NET_NAME="osintnet"

# As we have nice names, specify FLAT_NETWORK_BRIDGE
FLAT_NETWORK_BRIDGE="osvmnet"

# Do not use secure delete
CINDER_SECURE_DELETE=False

# Tempest
DEFAULT_INSTANCE_TYPE="m1.tiny"

# Compute settings
EXTRA_OPTS=("xenapi_disable_agent=True")
API_RATE_LIMIT=False
VIRT_DRIVER=xenserver

# Use a XenServer Image and the standard one
# The XenServer image is faster, however tempest requires the uec files
IMAGE_URLS="\
https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz,\
http://download.cirros-cloud.net/0.3.1/cirros-0.3.1-x86_64-uec.tar.gz"

DEFAULT_IMAGE_NAME="cirros-0.3.0-x86_64-disk"

# OpenStack VM settings
OSDOMU_VDI_GB=40

# Exercise settings
ACTIVE_TIMEOUT=500
TERMINATE_TIMEOUT=500

# Increase boot timeout for neutron tests:
BOOT_TIMEOUT=500

# DevStack settings
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/

# Turn off verbose, so console is nice and clean
VERBOSE=False

# XenAPI specific
XENAPI_CONNECTION_URL="http://$XENSERVER_IP"
VNCSERVER_PROXYCLIENT_ADDRESS="$XENSERVER_IP"

MULTI_HOST=1

# Skip boot from volume exercise
SKIP_EXERCISES="boot_from_volume"

ENABLED_SERVICES=g-api,g-reg,key,n-api,n-crt,n-obj,n-cpu,n-sch,horizon,mysql,rabbit,sysstat,tempest,s-proxy,s-account,s-container,s-object,cinder,c-api,c-vol,c-sch,n-cond,heat,h-api,h-api-cfn,h-api-cw,h-eng,n-net

# XEN_FIREWALL_DRIVER=nova.virt.xenapi.firewall.Dom0IptablesFirewallDriver
XEN_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver

# 9 Gigabyte for object store
SWIFT_LOOPBACK_DISK_SIZE=9000000

# Additional Localrc parameters here

LOCALRC_CONTENT_ENDS_HERE

cd tools/xen
./install_os_domU.sh
END_OF_XENSERVER_COMMANDS

if [ "$TEST_TYPE" == "none" ]; then
    exit 0
fi

# Run tests
on_xenserver << END_OF_XENSERVER_COMMANDS
set -exu
cd $TMPDIR
cd devstack*

GUEST_IP=\$(. "tools/xen/functions" && find_ip_by_name DevStackOSDomU 0)
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "stack@\$GUEST_IP" bash -s -- << END_OF_DEVSTACK_COMMANDS
set -exu

cd /opt/stack/devstack/
./exercise.sh

cd /opt/stack/tempest 
if [ "$TEST_TYPE" == "smoke" ]; then
    nosetests -sv --nologcapture --attr=type=smoke tempest
elif [ "$TEST_TYPE" == "full" ]; then
    nosetests -sv tempest/api tempest/scenario tempest/thirdparty tempest/cli
fi

END_OF_DEVSTACK_COMMANDS

END_OF_XENSERVER_COMMANDS
