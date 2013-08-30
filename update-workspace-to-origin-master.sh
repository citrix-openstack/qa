#!/bin/bash
set -eu

echo "Creating workspace..."
./create-workspace.sh
echo "Resetting workspace..."
./reset-workspace.sh
echo "Fetch remotes..."
./with-all-repos-in-workspace.sh git fetch --all
echo "Check out origin/master as a new branch..."
./with-all-repos-in-workspace.sh git checkout origin/master -B tmpbranch --no-track
