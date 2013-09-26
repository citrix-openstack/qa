#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 BRANCH_REF_NAME [SETUP_TYPE]

Generate a test script to the standard output

positional arguments:
 BRANCH_REF_NAME  Name of the ref/branch to be used.
 SETUP_TYPE       Type of setup, one of [nova-network, neutron] defaults to
                  nova-network.

An example run:

$0 build-1373962961 nova-network
EOF
exit 1
}

THIS_DIR=$(cd $(dirname "$0") && pwd)

. $THIS_DIR/lib/functions

TEMPLATE_NAME="$THIS_DIR/templates/tempest-smoke.sh"
BRANCH_REF_NAME="${1-$(print_usage_and_die)}"
SETUP_TYPE="${2-"nova-network"}"

EXTENSION_POINT="^# Additional Localrc parameters here$"
EXTENSIONS=$(mktemp)

# Set ubuntu install proxy
cat "$THIS_DIR/modifications/add-ubuntu-proxy-repos" >> $EXTENSIONS

# Set custom repos
{
    generate_repos | while read repo_record; do
        echo "$(var_name "$repo_record")=$(dst_repo "$repo_record")"
        echo "$(branch_name "$repo_record")=$BRANCH_REF_NAME"
    done
    cat << EOF
NOVA_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/nova/archive/$BRANCH_REF_NAME.zip"
NEUTRON_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/neutron/archive/$BRANCH_REF_NAME.zip"
EOF
} >> "$EXTENSIONS"

# Configure neutron if needed
if [ "$SETUP_TYPE" == "neutron" ]; then
    cat "$THIS_DIR/modifications/use-neutron" >> $EXTENSIONS
fi

# Configure VLAN Manager if needed
if [ "$SETUP_TYPE" == "nova-vlan" ]; then
    cat "$THIS_DIR/modifications/use-vlan" >> $EXTENSIONS
fi

# Extend template
sed \
    -e "/$EXTENSION_POINT/r  $EXTENSIONS" \
    "$TEMPLATE_NAME"

rm -f "$EXTENSIONS"
