#!/bin/bash

set -eux

. lib/functions

TEMPLATE_NAME="$1"
BRANCH_NAME="$2"

EXTENSION_POINT="^# Additional Localrc parameters here$"

REPOS_VERSIONS=$(mktemp)
{
    generate_repos | while read repo_record; do
        echo "$(var_name "$repo_record")=$(dst_repo "$repo_record")"
        echo "$(branch_name "$repo_record")=$BRANCH_NAME"
    done
    cat << EOF
NOVA_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/nova/zipball/$BRANCH_NAME"
NEUTRON_ZIPBALL_URL="http://gold.eng.hq.xensource.com/git/internal/builds/quantum/zipball/$BRANCH_NAME"
EOF
} > "$REPOS_VERSIONS"

sed \
    -e "/$EXTENSION_POINT/r  modifications/add-ubuntu-proxy-repos" \
    -e "/$EXTENSION_POINT/r  $REPOS_VERSIONS" \
    -e "s,^\(DEVSTACK_TGZ=\).*,\1http://gold.eng.hq.xensource.com/git/internal/builds/devstack/archive/$BRANCH_NAME.tar.gz,g" \
    "$TEMPLATE_NAME"
