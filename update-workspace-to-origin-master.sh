#!/bin/bash
set -eu

SOME_REPOS="${1:-}"

echo "Creating workspace..."
./create-workspace.sh
echo "Resetting workspace..."
./reset-workspace.sh
if [ -z "$SOME_REPOS" ]; then
    echo "Fetch origin..."
    ./with-all-repos-in-workspace.sh git_retry fetch origin
    echo "Check out origin/master as a new branch..."
    ./with-all-repos-in-workspace.sh git_retry checkout origin/master -B tmpbranch --no-track
else
    echo "Fetch origin..."
    ./with-some-repos-in-workspace.sh "$1" git_retry fetch origin
    echo "Check out origin/master as a new branch..."
    ./with-some-repos-in-workspace.sh "$1" git_retry checkout origin/master -B tmpbranch --no-track
fi
