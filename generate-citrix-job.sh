#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 BRANCH_REF_NAME [-t SETUP_TYPE] [-u UBUNTU_DISTRO] [-m UBUNTU_INST_HTTP_HOSTNAME] [-x]

Generate a test script to the standard output

positional arguments:
 BRANCH_REF_NAME  Name of the ref/branch to be used.
 SETUP_TYPE       Type of setup, one of [nova-network, neutron] defaults to
                  nova-network.
 UBUNTU_DISTRO    The ubuntu distribution to use [precise, saucy, trusty]
                  defaults to not specifying, so use whatever is defined in
                  localrc/xenrc.
 UBUNTU_INST_HTTP_HOSTNAME
                  Specify an ubuntu mirror to be used. Using the one specified
                  by .xenrc if not specified.

flags:
 -x               Create an externally usable script. If this flag is set, then
                  ubuntu repositories will not be overriden, and github will be
                  used.

An example run:

$0 build-1373962961

$@
EOF
exit 1
}

THIS_DIR=$(cd $(dirname "$0") && pwd)

. $THIS_DIR/lib/functions

TEMPLATE_NAME="$THIS_DIR/install-devstack-xen.sh"
INTERNAL_REPO_BASE="gold.eng.hq.xensource.com/git/internal/builds"
EXTERNAL_REPO_BASE="github.com/citrix-openstack-build"

# Defaults for options
SETUP_TYPE="nova-network"
UBUNTU_DISTRO=""
INTERNAL="true"
REPO_BASE="$INTERNAL_REPO_BASE"
UBUNTU_INST_HTTP_HOSTNAME=""

# Get positiona arguments
set +u
BRANCH_REF_NAME="$1"
shift || print_usage_and_die "ERROR: Please specify a branch name"
set -u

# Number of options passed to this script
REMAINING_OPTIONS="$#"

# Get optional parameters
set +e
while getopts ":t:u:m:x" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        t)
            SETUP_TYPE="$OPTARG"
            if ! [ "$SETUP_TYPE" = "nova-network" -o "$SETUP_TYPE" = "neutron" ]; then
                print_usage_and_die "ERROR: invalid value for SETUP_TYPE: $SETUP_TYPE"
            fi
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        u)
            UBUNTU_DISTRO="$OPTARG"
            if ! [ "$UBUNTU_DISTRO" = "precise" -o "$UBUNTU_DISTRO" = "saucy" -o "$UBUNTU_DISTRO" = "trusty" ]; then
                print_usage_and_die "ERROR: invalid value for UBUNTU_DISTRO: $UBUNTU_DISTRO"
            fi
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        m)
            UBUNTU_INST_HTTP_HOSTNAME="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        x)
            INTERNAL="false"
            REPO_BASE="$EXTERNAL_REPO_BASE"
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

EXTENSION_POINT="^# Additional Localrc parameters here$"
EXTENSIONS=$(mktemp)

# Set ubuntu install proxy for intenal script
if [ "true" = "$INTERNAL" ]; then
    cat "$THIS_DIR/modifications/add-ubuntu-proxy-repos" >> $EXTENSIONS
fi

# Set custom repos
{
    generate_repos | while read repo_record; do
        echo "$(var_name "$repo_record")=$(dst_repo "$repo_record")"
        echo "$(branch_name "$repo_record")=$BRANCH_REF_NAME"
    done
    cat << EOF
NOVA_ZIPBALL_URL="http://$REPO_BASE/nova/archive/$BRANCH_REF_NAME.zip"
NEUTRON_ZIPBALL_URL="http://$REPO_BASE/neutron/archive/$BRANCH_REF_NAME.zip"
EOF
} | sed -e "s,$INTERNAL_REPO_BASE,$REPO_BASE,g" >> "$EXTENSIONS"

function testing_trunk() {
    echo "$BRANCH_REF_NAME" | grep -q "os-trunk-test"
}

function neutron_setup() {
    [ "$SETUP_TYPE" = "neutron" ]
}

# Set FLAT_NETWORK_BRIDGE, but only if we are not testing trunk
if ! testing_trunk && ! neutron_setup ; then
    echo "FLAT_NETWORK_BRIDGE=osvmnet" >> $EXTENSIONS
fi

# Configure neutron if needed
if [ "$SETUP_TYPE" == "neutron" ]; then
    cat "$THIS_DIR/modifications/use-neutron" >> $EXTENSIONS
fi

# Configure VLAN Manager if needed
if [ "$SETUP_TYPE" == "nova-vlan" ]; then
    cat "$THIS_DIR/modifications/use-vlan" >> $EXTENSIONS
fi

# Configure distribution
if [ -n "$UBUNTU_DISTRO" ]; then
    echo "UBUNTU_INST_RELEASE=$UBUNTU_DISTRO" >> $EXTENSIONS
    echo "UBUNTU_INST_TEMPLATE_NAME=devstack_$UBUNTU_DISTRO" >> $EXTENSIONS
fi

# Configure mirror
if [ -n "$UBUNTU_INST_HTTP_HOSTNAME" ]; then
   echo "UBUNTU_INST_HTTP_HOSTNAME=$UBUNTU_INST_HTTP_HOSTNAME" >> $EXTENSIONS
fi

# Extend template
sed \
    -e "/$EXTENSION_POINT/r  $EXTENSIONS" \
    -e "s,^\(DEVSTACK_TGZ=\).*,\1http://$REPO_BASE/devstack/archive/$BRANCH_REF_NAME.tar.gz,g" \
    "$TEMPLATE_NAME"

rm -f "$EXTENSIONS"
