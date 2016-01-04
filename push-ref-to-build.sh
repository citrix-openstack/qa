#!/bin/bash
set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 TARGET_REF REPOS

Push current HEAD as TARGET_REF to the build remote.

positional arguments:
 TARGET_REF      Name of the ref to be pushed.
 REPOS           (Optional) Space separated list of repos to push

example:
 $0 refs/citrix-builds/build-002 "openstack/nova openstack/devstack"
EOF
exit 1
}


TARGET_REF="${1-$(print_usage_and_die)}"
SOME_REPOS="${2:-}"

if [ -z "$SOME_REPOS" ]; then
    echo "updating $TARGET_REF to point to HEAD"
    ./with-some-repos-in-workspace.sh "$SOME_REPOS" git update-ref "$TARGET_REF" HEAD
    echo "Pushing HEAD as a reference $TARGET_REF to build remote"
    ./with-some-repos-in-workspace.sh "$SOME_REPOS" git push --quiet build HEAD:"$TARGET_REF"
    echo "Pushing tags"
    ./with-some-repos-in-workspace.sh "$SOME_REPOS" git push --tags build
else
    echo "updating $TARGET_REF to point to HEAD"
    ./with-all-repos-in-workspace.sh git update-ref "$TARGET_REF" HEAD
    echo "Pushing HEAD as a reference $TARGET_REF to build remote"
    ./with-all-repos-in-workspace.sh git push --quiet build HEAD:"$TARGET_REF"
    echo "Pushing tags"
    ./with-all-repos-in-workspace.sh git push --tags build
fi
