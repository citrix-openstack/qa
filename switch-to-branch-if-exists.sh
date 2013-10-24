#!/bin/bash
set -eu

BRANCHNAME="$1"

thisdir="$(dirname $(readlink -f $0))"

./with-all-repos-in-workspace.sh bash "$thisdir/safe-switch-to-branch.sh" "$BRANCHNAME"
