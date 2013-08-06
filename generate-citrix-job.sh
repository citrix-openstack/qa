#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 BRANCH_NAME [SETUP_TYPE]

Generate a test script to the standard output

positional arguments:
 BRANCH_NAME      Name of the branch to be used, use 'latest' to use the latest
                  branch
 SETUP_TYPE       Type of setup, one of [nova-network, neutron] defaults to
                  nova-network

An example run:

$0 build-1373962961 nova-network
EOF
exit 1
}

THIS_DIR=$(cd $(dirname "$0") && pwd)

. $THIS_DIR/lib/functions

TEMPLATE_NAME="$THIS_DIR/templates/tempest-smoke.sh"
BRANCH_NAME="${1-$(print_usage_and_die)}"
SETUP_TYPE="${2-"nova-network"}"

if [ "$BRANCH_NAME" == "latest" ]; then
    BRANCH_NAME=$(wget -qO - "http://gold.eng.hq.xensource.com/gitweb/?p=internal/builds/status.git;a=blob_plain;f=latest_branch;hb=HEAD")
fi

EXTENSION_POINT="^# Additional Localrc parameters here$"
EXTENSIONS=$(mktemp)

# Set ubuntu install proxy
cat "$THIS_DIR/modifications/add-ubuntu-proxy-repos" >> $EXTENSIONS

# Set custom repos
{
    generate_repos | while read repo_record; do
        echo "$(var_name "$repo_record")=$(dst_repo "$repo_record")"
        echo "$(branch_name "$repo_record")=$BRANCH_NAME"
    done
    cat << EOF
NOVA_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/nova/zipball/$BRANCH_NAME"
NEUTRON_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/neutron/zipball/$BRANCH_NAME"
EOF
} > "$EXTENSIONS"

# Configure neutron if needed
if [ "$SETUP_TYPE" == "neutron" ]; then
    cat "$THIS_DIR/modifications/use-neutron" >> $EXTENSIONS
fi

# Extend template
sed \
    -e "/$EXTENSION_POINT/r  $EXTENSIONS" \
    -e "s,^\(DEVSTACK_TGZ=\).*,\1http://gold.eng.hq.xensource.com/git/internal/builds/devstack/archive/$BRANCH_NAME.tar.gz,g" \
    "$TEMPLATE_NAME"

rm -f "$EXTENSIONS"
