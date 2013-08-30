#!/bin/bash
set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 TARGET_REF

Push current HEAD as TARGET_REF to the build remote.

positional arguments:
 TARGET_REF      Name of the ref to be pushed.

example:
 $0 refs/citrix-builds/build-002
EOF
exit 1
}

TARGET_REF="${1-$(print_usage_and_die)}"

echo "updating $TARGET_REF to point to HEAD"
./with-all-repos-in-workspace.sh git update-ref "$TARGET_REF" HEAD
echo "Pushing HEAD as a reference $TARGET_REF to build remote"
./with-all-repos-in-workspace.sh git push --quiet build HEAD:"$TARGET_REF"
echo "Pushing tags"
./with-all-repos-in-workspace.sh git push --tags build
