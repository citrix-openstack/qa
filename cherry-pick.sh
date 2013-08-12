#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 BUILD_BRANCH_NAME [ORIGINAL_BRANCH]

Fetch changes on top of ORIGINAL_BRANCH, push to a new branch BUILD_BRANCH_NAME

positional arguments:
 BUILD_BRANCH_NAME  The target branch to be created.
 ORIGINAL_BRANCH    The original branch (specify latest for the latest)
EOF
exit 1
}


. lib/functions

BUILD_BRANCH_NAME="${1-$(print_usage_and_die)}"
ORIGINAL_BRANCH=${2:-latest}

# We depend on this script to generate the changes
[ -x ../changes/get_patches.sh ]

if [ "$ORIGINAL_BRANCH" = "latest" ]; then
    ORIGINAL_BRANCH=$(wget -qO - "http://gold.eng.hq.xensource.com/gitweb/?p=internal/builds/status.git;a=blob_plain;f=latest_branch;hb=HEAD")
fi

echo "Updating workspace..."
./create_workspace.sh
echo "Fetch latest changes from build remotes..." 
./with_all_repos.sh git fetch build
echo "Resetting local repositories..."
./reset_all_repos.sh
echo "Checking out branch build/$ORIGINAL_BRANCH to $BUILD_BRANCH_NAME"
./with_all_repos.sh \
  git checkout -q "build/$ORIGINAL_BRANCH" -B $BUILD_BRANCH_NAME > /dev/null
echo "Cherry - picking changes"
../changes/get_patches.sh | ./cherry_pick_changes_to_workspace.sh
echo "Pushing branches"
./with_all_repos.sh git push --tags --quiet build "$BUILD_BRANCH_NAME"

