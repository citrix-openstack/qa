#!/bin/bash
set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 XENSERVER XENSERVER_PASS PRIVKEY <optional arguments>

A simple script to use devstack to setup an OpenStack, and optionally
run tests on it. This script should be executed on an operator machine, and
it will execute commands through ssh on the remote XenServer specified.

positional arguments:
 XENSERVER          The address of the XenServer
 XENSERVER_PASS     The root password for the XenServer
 PRIVKEY            A passwordless private key to be used for installation.
                    This key will be copied over to the xenserver host, and will
                    be used for migration/resize tasks if multiple XenServers
                    used.  If '-' is passed, assume the key is provided by an agent

optional arguments:
 -t TEST_TYPE          Type of the tests to run. One of [none, exercise, smoke, full]
                       defaults to none
 -d DEVSTACK_SRC       An URL pointing to a tar.gz snapshot of devstack. This
                       defaults to the official devstack repository.  Can also be a local
                       file location.
 -l LOG_FILE_DIRECTORY The directory in which to store the devstack logs on failure.
 -j JEOS_URL           An URL for an xva containing an exported minimal OS template
                       with the name jeos_template_for_devstack, to be used
                       as a starting point.
 -e JEOS_FILENAME      Save a JeOS xva to the given filename and quit. If this
                       parameter is specified, no private key setup or devstack
                       installation will be done. The exported file could be
                       re-used later by putting it to a webserver, and specifying
                       JEOS_URL.
 -s SUPP_PACK_URL      URL to a supplemental pack that will be installed on the host
                       before running any tests.  The host will not be rebooted after
                       installing the supplemental pack, so new kernels will not be
                       picked up.

flags:
 -f                 Force SR replacement. If your XenServer has an LVM type SR,
                    it will be destroyed and replaced with an ext SR.
                    WARNING: This will destroy your actual default SR !

 -n                 No devstack, just create the JEOS template that could be
                    exported to an xva using the -e option.


An example run:

  # Create a passwordless ssh key
  ssh-keygen -t rsa -N "" -f devstack_key.priv

  # Install devstack
  $0 XENSERVER mypassword devstack_key.priv

$@
EOF
exit 1
}

# Defaults for optional arguments
DEVSTACK_SRC="https://github.com/openstack-dev/devstack/archive/master.tar.gz"
TEST_TYPE="none"
FORCE_SR_REPLACEMENT="false"
EXIT_AFTER_JEOS_INSTALLATION=""
LOG_FILE_DIRECTORY=""
JEOS_URL=""
JEOS_FILENAME=""
SUPP_PACK_URL=""
SCREEN_LOGDIR="/opt/stack/devstack_logs"

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
while getopts ":t:d:fnl:j:e:s:" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        t)
            TEST_TYPE="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            if ! [ "$TEST_TYPE" = "none" -o "$TEST_TYPE" = "smoke" -o "$TEST_TYPE" = "full" -o "$TEST_TYPE" = "exercise" ]; then
                print_usage_and_die "$TEST_TYPE - Invalid value for TEST_TYPE"
            fi
            ;;
        d)
            DEVSTACK_SRC="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        f)
            FORCE_SR_REPLACEMENT="true"
            ;;
        n)
            EXIT_AFTER_JEOS_INSTALLATION="true"
            ;;
        l)
            LOG_FILE_DIRECTORY="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        j)
            JEOS_URL="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        e)
            JEOS_FILENAME="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        s)
            SUPP_PACK_URL="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
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
    -o UserKnownHostsFile=/dev/null"

if [ "$PRIVKEY" != "-" ]; then
  _SSH_OPTIONS="$_SSH_OPTIONS -i $PRIVKEY"
fi

# Print out summary
cat << EOF
XENSERVER:      $XENSERVER
XENSERVER_PASS: $XENSERVER_PASS
PRIVKEY:        $PRIVKEY
TEST_TYPE:      $TEST_TYPE
DEVSTACK_SRC:   $DEVSTACK_SRC

FORCE_SR_REPLACEMENT: $FORCE_SR_REPLACEMENT
JEOS_URL:             ${JEOS_URL:-template will not be imported}
JEOS_FILENAME:        ${JEOS_FILENAME:-not exporting JeOS}
SUPP_PACK_URL:        ${SUPP_PACK_URL:-no supplemental pack}
EOF

# Helper function
function on_xenserver() {
    ssh $_SSH_OPTIONS "root@$XENSERVER" bash -s --
}

function assert_tool_exists() {
    local tool_name

    tool_name="$1"

    if ! which "$tool_name" >/dev/null; then
        echo "ERROR: $tool_name is required for this script, please install it on your system! " >&2
        exit 1
    fi
}

if [ -z "$JEOS_FILENAME" ]; then
    if [ "$PRIVKEY" != "-" ]; then
      echo "Setup ssh keys on XenServer..."
      tmp_dir="$(mktemp -d --suffix=OpenStack)"
      echo "Use $tmp_dir for public/private keys..."
      cp $PRIVKEY "$tmp_dir/devstack"
      ssh-keygen -y -f $PRIVKEY > "$tmp_dir/devstack.pub"
      assert_tool_exists sshpass
      echo "Setup public key to XenServer..."
      DEVSTACK_PUB=$(cat $tmp_dir/devstack.pub)
      sshpass -p "$XENSERVER_PASS" \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            root@$XENSERVER "echo $DEVSTACK_PUB >> ~/.ssh/authorized_keys"
      scp $_SSH_OPTIONS $PRIVKEY "root@$XENSERVER:.ssh/id_rsa"
      scp $_SSH_OPTIONS $tmp_dir/devstack.pub "root@$XENSERVER:.ssh/id_rsa.pub"
      rm -rf "$tmp_dir"
      unset tmp_dir
      echo "OK"
    fi
else
    echo -n "Exporting JeOS template..."
    on_xenserver << END_OF_EXPORT_COMMANDS
set -eu
JEOS_TEMPLATE="\$(xe template-list name-label="jeos_template_for_devstack" --minimal)"

if [ -z "\$JEOS_TEMPLATE" ]; then
    echo "FATAL: jeos_template_for_devstack not found"
    exit 1
fi
rm -f /root/jeos-for-devstack.xva
xe template-export template-uuid="\$JEOS_TEMPLATE" filename="/root/jeos-for-devstack.xva" compress=true
END_OF_EXPORT_COMMANDS
    echo "OK"

    echo -n "Copy exported template to local file..."
    if scp -3 $_SSH_OPTIONS "root@$XENSERVER:/root/jeos-for-devstack.xva" "$JEOS_FILENAME"; then
        echo "OK"
        RETURN_CODE=0
    else
        echo "FAILED"
        RETURN_CODE=1
    fi
    echo "Cleanup: delete exported template from XenServer"
    on_xenserver << END_OF_CLEANUP
set -eu
rm -f /root/jeos-for-devstack.xva
END_OF_CLEANUP
    echo "JeOS export done, exiting."
    exit $RETURN_CODE
fi

TMPDIR=$(echo "mktemp -d" | on_xenserver)

function copy_logs_on_failure() {
    set +e
    $@
    EXIT_CODE=$?
    set -e
    if [ $EXIT_CODE -ne 0 ]; then
        copy_logs
        exit $EXIT_CODE
    fi
}

function copy_logs() {
    if [ -n "$LOG_FILE_DIRECTORY" ]; then
        on_xenserver << END_OF_XENSERVER_COMMANDS
set -xu
cd $TMPDIR
cd devstack*

mkdir -p /root/artifacts

GUEST_IP=\$(. "tools/xen/functions" && find_ip_by_name DevStackOSDomU 0)
if [ -n \$GUEST_IP ]; then
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    stack@\$GUEST_IP "tar --ignore-failed-read -czf - ${SCREEN_LOGDIR}/* /opt/stack/tempest/*.xml" > \
    /root/artifacts/domU.tgz < /dev/null || true
fi
tar --ignore-failed-read -czf /root/artifacts/dom0.tgz /var/log/messages* /var/log/xensource* /var/log/SM* || true
END_OF_XENSERVER_COMMANDS

        mkdir -p $LOG_FILE_DIRECTORY
        scp $_SSH_OPTIONS $XENSERVER:artifacts/* $LOG_FILE_DIRECTORY
        tar -xzf $LOG_FILE_DIRECTORY/domU.tgz opt/stack/tempest/tempest-full.xml -O \
           > $LOG_FILE_DIRECTORY/tempest-full.xml || true
    fi
}

echo -n "Generate id_rsa.pub..."
echo "ssh-keygen -y -f .ssh/id_rsa > .ssh/id_rsa.pub" | on_xenserver
echo "OK"

echo -n "Verify that XenServer can log in to itself..."
if echo "ssh -o StrictHostKeyChecking=no $XENSERVER true" | on_xenserver; then
    echo "OK"
else
    echo ""
    echo ""
    echo "ERROR: XenServer couldn't authenticate to itself. This might"
    echo "be caused by having a key originally installed on XenServer"
    echo "consider using the -w parameter to wipe all your ssh settings"
    echo "on XenServer."
    exit 1
fi

echo -n "Verify XenServer has an ext type default SR..."
copy_logs_on_failure on_xenserver << END_OF_SR_OPERATIONS
set -eu

# Verify the host is suitable for devstack
defaultSR=\$(xe pool-list params=default-SR minimal=true)
currentSrType=\$(xe sr-param-get uuid=\$defaultSR param-name=type)
if [ "\$currentSrType" != "ext" -a "\$currentSrType" != "nfs" -a "\$currentSrType" != "ffs" -a "\$currentSrType" != "file" ]; then
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
    echo "ERROR: The xenserver host must have an EXT3/NFS/FFS/File SR as the default SR"
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
xe host-list params=address minimal=true
GET_XENSERVER_IP
)
if [ -z "$XENSERVER_IP" ]; then
    echo "Failed to detect the IP address of XenServer"
    exit 1
fi
echo "OK"

if [ -n "$SUPP_PACK_URL" ]; then
    echo -n "Applying supplemental pack"
    on_xenserver <<SUPP_PACK
set -eu
wget -qO /root/supp_pack_for_devstack.iso $SUPP_PACK_URL
xe-install-supplemental-pack /root/supp_pack_for_devstack.iso
reboot
SUPP_PACK
    echo -n "Rebooted host; waiting 10 minutes"
    sleep 10m
fi

echo -n "Hack ISCSISR.py on XenServer (original saved to /root/ISCSISR.py.orig)..."
on_xenserver << HACK_ISCSI_SR
set -eu

iscsi_target_file=""
for candidate_file in "/opt/xensource/sm/ISCSISR.py" "/usr/lib64/xcp-sm/ISCSISR.py"; do
    if [ -e "\$candidate_file" ]; then
        iscsi_target_file=\$candidate_file
    fi
done
if [ -n "\$iscsi_target_file" ]; then
    if ! [ -e "/root/ISCSISR.py.orig" ]; then
        cp \$iscsi_target_file /root/ISCSISR.py.orig
    fi
    sed -e "s/'phy'/'aio'/g" /root/ISCSISR.py.orig > \$iscsi_target_file
fi
HACK_ISCSI_SR
echo "OK"

if [ -n "$JEOS_URL" ]; then
    echo "(re-)importing JeOS template"
    on_xenserver << END_OF_JEOS_IMPORT
set -eu
JEOS_TEMPLATE="\$(xe template-list name-label="jeos_template_for_devstack" --minimal)"

if [ -n "\$JEOS_TEMPLATE" ]; then
    echo "  jeos_template_for_devstack already exist, uninstalling"
    xe template-uninstall template-uuid="\$JEOS_TEMPLATE" force=true > /dev/null
fi

rm -f /root/jeos-for-devstack.xva
echo "  downloading $JEOS_URL to /root/jeos-for-devstack.xva"
wget -qO /root/jeos-for-devstack.xva "$JEOS_URL"
echo "  importing /root/jeos-for-devstack.xva"
xe vm-import filename=/root/jeos-for-devstack.xva
rm -f /root/jeos-for-devstack.xva
echo "  verify template imported"
JEOS_TEMPLATE="\$(xe template-list name-label="jeos_template_for_devstack" --minimal)"
if [ -z "\$JEOS_TEMPLATE" ]; then
    echo "FATAL: template jeos_template_for_devstack does not exist after import."
    exit 1
fi

END_OF_JEOS_IMPORT
    echo "OK"
fi

if [ -e $DEVSTACK_SRC ]; then
copy_logs_on_failure on_xenserver << END_OF_XENSERVER_COMMANDS
set -eu

mkdir -p $TMPDIR/devstack-local
END_OF_XENSERVER_COMMANDS
    scp $_SSH_OPTIONS -r $DEVSTACK_SRC/* "root@$XENSERVER:$TMPDIR/devstack-local"
else
copy_logs_on_failure on_xenserver << END_OF_XENSERVER_COMMANDS
set -exu

cd $TMPDIR

wget "$DEVSTACK_SRC" -O _devstack.tgz
tar -xzf _devstack.tgz
cd devstack*
END_OF_XENSERVER_COMMANDS
fi

# set nounset for $NOVA_CONF
set +u

copy_logs_on_failure on_xenserver << END_OF_XENSERVER_COMMANDS
set -exu

cd $TMPDIR

cd devstack*

cat << LOCALCONF_CONTENT_ENDS_HERE > local.conf
# ``local.conf`` is a user-maintained settings file that is sourced from ``stackrc``.
# This gives it the ability to override any variables set in ``stackrc``.
# The ``localrc`` section replaces the old ``localrc`` configuration file.
# Note that if ``localrc`` is present it will be used in favor of this section.
# --------------------------------
[[local|localrc]]

enable_plugin os-xenapi https://github.com/openstack/os-xenapi.git

# Passwords
MYSQL_PASSWORD=citrix
SERVICE_TOKEN=citrix
ADMIN_PASSWORD=citrix
SERVICE_PASSWORD=citrix
RABBIT_PASSWORD=citrix
GUEST_PASSWORD=citrix
XENAPI_PASSWORD="$XENSERVER_PASS"
SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"

# Nice short names, so we could export an XVA
VM_BRIDGE_OR_NET_NAME="osvmnet"
PUB_BRIDGE_OR_NET_NAME="ospubnet"
XEN_INT_BRIDGE_OR_NET_NAME="osintnet"

# Do not use secure delete
CINDER_SECURE_DELETE=False

# Compute settings
VIRT_DRIVER=xenserver

# OpenStack VM settings
OSDOMU_VDI_GB=30
OSDOMU_MEM_MB=8192

TERMINATE_TIMEOUT=90
BUILD_TIMEOUT=600

# DevStack settings
LOGFILE=${SCREEN_LOGDIR}/stack.log
SCREEN_LOGDIR=${SCREEN_LOGDIR}

UBUNTU_INST_HTTP_HOSTNAME=archive.ubuntu.com
UBUNTU_INST_HTTP_DIRECTORY=/ubuntu

# Turn on verbosity (password input does not work otherwise)
VERBOSE=True

# XenAPI specific
XENAPI_CONNECTION_URL="http://$XENSERVER_IP"
VNCSERVER_PROXYCLIENT_ADDRESS="$XENSERVER_IP"

# Neutron specific part
ENABLED_SERVICES+=neutron,q-domua
Q_ML2_PLUGIN_MECHANISM_DRIVERS=openvswitch

Q_ML2_PLUGIN_TYPE_DRIVERS=vlan,flat
ENABLE_TENANT_TUNNELS=False
ENABLE_TENANT_VLANS=True
Q_ML2_TENANT_NETWORK_TYPE=vlan
ML2_VLAN_RANGES="physnet1:1100:1200"

PUB_IP=172.24.4.1
SUBNETPOOL_PREFIX_V4=192.168.10.0/24
NETWORK_GATEWAY=192.168.10.1

VLAN_INTERFACE=eth1
PUBLIC_INTERFACE=eth2

# Nova user specific configuration
# --------------------------------
[[post-config|\\\$NOVA_CONF]]
[DEFAULT]
disk_allocation_ratio = 2.0

# Neutron ovs bridge mapping
[[post-config|\\\$NEUTRON_CORE_PLUGIN_CONF]]
[ovs]
bridge_mappings = physnet1:br-eth1,public:br-ex

LOCALCONF_CONTENT_ENDS_HERE

# unset nounset for $NOVA_CONF
set -u

# XenServer doesn't have nproc by default - but it's used by stackrc.
# Fake it up if one doesn't exist
set +e
which nproc > /dev/null 2>&1
if [ \$? -ne 0 ]; then
  cat >> /usr/local/bin/nproc << END_OF_NPROC
#!/bin/bash
cat /proc/cpuinfo | grep -c processor
END_OF_NPROC
  chmod +x /usr/local/bin/nproc
fi

cd tools/xen
EXIT_AFTER_JEOS_INSTALLATION="$EXIT_AFTER_JEOS_INSTALLATION" ./install_os_domU.sh
END_OF_XENSERVER_COMMANDS

if [ "$TEST_TYPE" == "none" ]; then
    exit 0
fi

# Run tests
copy_logs_on_failure on_xenserver << END_OF_XENSERVER_COMMANDS
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

cd /opt/stack/tempest
if [ "$TEST_TYPE" == "exercise" ]; then
    tox -eall tempest.scenario.test_server_basic_ops
elif [ "$TEST_TYPE" == "smoke" ]; then
    #./run_tests.sh -s -N
    tox -esmoke
elif [ "$TEST_TYPE" == "full" ]; then
    #nosetests -sv --with-xunit --xunit-file=tempest-full.xml tempest/api tempest/scenario tempest/thirdparty tempest/cli
    tox -efull
fi

END_OF_DEVSTACK_COMMANDS

END_OF_XENSERVER_COMMANDS

copy_logs
