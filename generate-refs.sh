#!/bin/bash
set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 REPOS TARGET_REF

Generate a list of REPOS with either the current head (from gerrit) or
the specified REF (citrix branch)

positional arguments:
 REPOS           Space separated list of repos that we use the local ref for
 TARGET_REF      Name of the ref to be pushed.

example:
 $0 "openstack/nova openstack/devstack" refs/citrix-builds/build-002
EOF
exit 1
}

REPOS="${1-$(print_usage_and_die)}"
BRANCH_REF_NAME="${2-$(print_usage_and_die)}"

. lib/functions

assert_no_new_repos

function get_custom_repo_lines
{
    REPOS="$1"
    full_name="$2"
    repo_record="$3"
    BRANCH_REF_NAME="$4"

    for repo_test in $REPOS; do
        if [ "X${repo_test}.gitX" != "X${full_name}X" ]; then
	    continue
	fi
        echo "$(var_name "$repo_record")=$(public_repo "$repo_record")"
        echo "$(branch_name "$repo_record")=$BRANCH_REF_NAME"
    done
}

static_repos | while read repo_record; do
    full_name=$(repo_full_name "$repo_record")
    custom_lines=$(get_custom_repo_lines "$REPOS" "$full_name" "$repo_record" "$BRANCH_REF_NAME")
    if [ -z "$custom_lines" ]; then
	# Devstack is a special case since stackrc is contained in it
	if [ "$(var_name "$repo_record")" == "DEVSTACK_REPO" ]; then
	    continue
	fi
	remote_repo_line=$(repo_lines | grep "$(var_name "$repo_record")" | sed -e 's#\${GIT_BASE}#git://git.openstack.org#')
	remote_repo="$(echo $remote_repo_line | sed -e 's#.*-\([a-z]*://.*.git\).*#\1#g')"
	echo "$(var_name "$repo_record")=$remote_repo"
	echo "$(branch_name "$repo_record")=$(git ls-remote $remote_repo HEAD | cut -f 1)"
    else
	echo "$custom_lines"
    fi
done
