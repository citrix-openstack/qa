#!/bin/bash
set -eu

BRANCHNAME="$1"

checkout_name=`git show-ref | grep -m 1 "$BRANCHNAME" | awk '{print $2}'`
if [ -n "$checkout_name" ]; then
    git checkout "$checkout_name" -B tmpbranch --no-track
else
    echo "  WARNING: $BRANCHNAME does not exist [$PWD]"
fi

