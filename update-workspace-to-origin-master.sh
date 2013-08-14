#!/bin/bash
set -eu

echo "Creating workspace..."
./create-workspace.sh
echo "Resetting workspace..."
./reset-workspace.sh
echo "Fetch latest changes from origin remotes..."
./with-all-repos-in-workspace.sh git fetch origin refs/heads/master
echo "Checking out FETCH_HEAD as tmpbranch"
./with-all-repos-in-workspace.sh git checkout FETCH_HEAD -B tmpbranch
