#!/bin/bash
set -eux

BRANCHNAME="${1-$(print_usage_and_die)}"
SOME_REPOS="${2:-ALL}"

thisdir="$(dirname $(readlink -f $0))"

if [ "$SOME_REPOS" == "ALL" ]; then
    ./with-all-repos-in-workspace.sh bash "$thisdir/safe-switch-to-branch.sh" "$BRANCHNAME"
else
    ./with-some-repos-in-workspace.sh "$SOME_REPOS" bash "$thisdir/safe-switch-to-branch.sh" "$BRANCHNAME"
fi
