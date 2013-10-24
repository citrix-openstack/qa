#!/bin/bash
set -eu

BRANCHNAME="$1"

if git show-ref | grep -q "$BRANCHNAME"; then
    git checkout "$BRANCHNAME" -B tmpbranch --no-track
else
    echo "  WARNING: $BRANCHNAME does not exist [$PWD]"
fi

