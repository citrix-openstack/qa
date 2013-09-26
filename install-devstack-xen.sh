#!/bin/bash
#
# This script installs a DevStack DomU VM on
# the specified XenServer.
set -e

TEMPLATE_LOCALRC="localrc.template"

function syntax {
    echo "Syntax: $0 <private key> <host> <root password>"
    echo "Environment variables \$PrivID, \$Server and"\
	" \$XenServerPassword can be used as an alternative"
    exit 1
}

function print_template {
    cat <<EOF
# Passwords
MYSQL_PASSWORD=citrix
SERVICE_TOKEN=citrix
ADMIN_PASSWORD=citrix
SERVICE_PASSWORD=citrix
RABBIT_PASSWORD=citrix
# This is the password for your DomU (for both stack and root users)
GUEST_PASSWORD=citrix
# IMPORTANT: The following must be set to your dom0 root password!
XENAPI_PASSWORD=%XenServerPassword%
# As swift is enabled by default, we need a hash for it:
SWIFT_HASH="66a3d6b56c1f479c8b4e70ab5c2000f5"

# Nice short names, so we could use them as bridge names as well
VM_BRIDGE_OR_NET_NAME="osvmnet"
PUB_BRIDGE_OR_NET_NAME="ospubnet"
XEN_INT_BRIDGE_OR_NET_NAME="osintnet"

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

MULTI_HOST=1
# XEN_FIREWALL_DRIVER=nova.virt.xenapi.firewall.Dom0IptablesFirewallDriver
XEN_FIREWALL_DRIVER=nova.virt.firewall.NoopFirewallDriver

#
# Volume settings
#
# make tempest pass by having bigger volume file
VOLUME_BACKING_FILE_SIZE=10000M

# Use a custom repository, and a proxy
#UBUNTU_INST_HTTP_HOSTNAME="mirror.anl.gov"
#UBUNTU_INST_HTTP_DIRECTORY="/pub/ubuntu"
#UBUNTU_INST_HTTP_PROXY="http://gold.eng.hq.xensource.com:8000"

#
# exercise.sh settings
#
# DISABLE Boot from Volume
SKIP_EXERCISES="boot_from_volume"



# Devstack Settings
## Logging
LOGFILE=/tmp/devstack/log/stack.log
SCREEN_LOGDIR=/tmp/devstack/log/
VERBOSE=False
## Enabled services
ENABLED_SERVICES+=,tempest,
EOF
}

if [ ! -e $TEMPLATE_LOCALRC ]; then
    echo
    echo "Template localrc $TEMPLATE_LOCALRC not found: generating new template"
    echo
    print_template > $TEMPLATE_LOCALRC
fi

# Temporary directory
tmpdir=`mktemp -d`
trap "rm -rf $tmpdir" EXIT

PrivID=${1:-$PrivID}
Server=${2:-$Server}
XenServerPassword=${3:-$XenServerPassword}
XenServerVmVlan=${XenServerVmVlan:-24}

[ -z $Server ] && syntax
[ -z $XenServerPassword ] && syntax
[ -z $XenServerVmVlan ]&& syntax

if [ ! -e $PrivID ]; then
    echo "ID file $PrivID does not exist; Please specify valid private key"
    exit 1
fi
ssh-keygen -y -f $PrivID > $tmpdir/key.pub

ssh_options="-o BatchMode=yes -o StrictHostKeyChecking=no "
ssh_options+="-o UserKnownHostsFile=/dev/null -i $PrivID"

# Now we have our variables set up, ensure we don't mis-type them
set -u

# Tolerate this ssh failing - we might need to copy the key across
set +e
ssh -o LogLevel=quiet $ssh_options root@$Server /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    set -e
    echo "Please supply password for ssh-copy-id.  " \
        "This should be the last time the password is needed:"
    ssh-copy-id -i $tmpdir/key.pub root@$Server
fi
set -e


GENERATED_LOCALRC=$tmpdir\localrc

# Generate localrc
cat $TEMPLATE_LOCALRC |
sed -e "s,%XenServerVmVlan%,$XenServerVmVlan,g;
        s,%XenServerPassword%,$XenServerPassword,g;
" > $GENERATED_LOCALRC

LocalrcAppend=${LocalrcAppend-"localrc.append"}
[ -e "${LocalrcAppend}" ] && ( cat "$LocalrcAppend" >> $GENERATED_LOCALRC ) || \
    echo "$LocalrcAppend was not found, not appending to localrc"

set -x

# The parmaters expected are:
# $Server - XenServer host for compute DomU
# $XenServerVmVlan - Vlan ID
# $XenServerPassword - Password for your XenServer

# $DevStackURL (optional) - URL of the devstack zip file
# $CleanTemplates (default:false) - If true, clean the templates

DevStackURL=${DevStackURL-"https://github.com/openstack-dev/devstack/zipball/master"}
CleanTemplates="${CleanTemplates-true}"
DhcpTimeout=120

#
# Add the clean templates setting
# and correct the IP address for dom0
#
XenApiIP=`ssh $ssh_options root@$Server "ifconfig xenbr0 | grep \"inet addr\" | cut -d \":\" -f2 | sed \"s/ .*//\""`
cat <<EOF >> $GENERATED_LOCALRC
CLEAN_TEMPLATES=$CleanTemplates
XENAPI_CONNECTION_URL="http://$XenApiIP"
VNCSERVER_PROXYCLIENT_ADDRESS=$XenApiIP
EOF

#
# Show the content on the localrc file
#

set +x
echo "Content of localrc file:"
cat $GENERATED_LOCALRC
echo "** end of localrc file **"

#
# Run the next steps on the XenServer host
#

#
# Clean directory, create directory and
# copy what we need to the XenServer
#
SCRIPT_TMP_DIR=/tmp/jenkins_test

cat > $tmpdir/install_devstack.sh <<EOF
#!/bin/bash
set -eux

# Verify the host is suitable for devstack
defaultSR=\`xe pool-list params=default-SR minimal=true\`
if [ "\`xe sr-param-get uuid=\$defaultSR param-name=type\`" != "ext" ]; then
    echo ""
    echo "ERROR: The xenserver host must have an EXT3 SR as the default SR"
    echo ""
    echo "Trying to replace the LVM SR with an EXT SR"

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
fi

rm -rf $SCRIPT_TMP_DIR
mkdir -p $SCRIPT_TMP_DIR

wget -nv --no-check-certificate $DevStackURL -O $SCRIPT_TMP_DIR/devstack.zip
# Remove the top-level directory (<user>-<repo>-<commit>)
# so the output is in a "devstack" directory
unzip -oq $SCRIPT_TMP_DIR/devstack.zip -d $SCRIPT_TMP_DIR/tmpunzip
mv $SCRIPT_TMP_DIR/tmpunzip/* $SCRIPT_TMP_DIR/devstack
rm -rf $SCRIPT_TMP_DIR/tmpunzip

preseedcfg=$SCRIPT_TMP_DIR/devstack/tools/xen/devstackubuntupreseed.cfg
# Additional DHCP timeout
sed -ie "s,#\(d-i netcfg/dhcp_timeout string\).*,\1 ${DhcpTimeout},g" \$preseedcfg

cp /tmp/localrc $SCRIPT_TMP_DIR/devstack/localrc

pushd $SCRIPT_TMP_DIR/devstack/tools/xen/
./install_os_domU.sh
popd
EOF

chmod +x $tmpdir/install_devstack.sh
echo
echo "*** Content of install_devstack.sh ***"
cat $tmpdir/install_devstack.sh
echo "*** End of install_devstack.sh ***"

set -x

scp $ssh_options $PrivID "root@$Server:~/.ssh/id_rsa"
scp $ssh_options $tmpdir/key.pub "root@$Server:~/.ssh/id_rsa.pub"
scp $ssh_options "$GENERATED_LOCALRC" "root@$Server:/tmp/localrc"
scp $ssh_options "$tmpdir/install_devstack.sh" "root@$Server:/tmp/install_devstack.sh"
ssh $ssh_options root@$Server "chmod +x /tmp/install_devstack.sh && /tmp/install_devstack.sh" \
    " | tee $SCRIPT_TMP_DIR/install_devstack.log"
