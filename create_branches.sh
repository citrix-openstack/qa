#!/bin/bash
set -eu

. lib/functions

assert_no_new_repos

BRANCH_NAME="build-$(date +%s)"

    
clone_status_repo "git://gold.eng.hq.xensource.com/git/internal/builds/status.git" status

pull_status_repo status

PREV_BRANCH=$(read_latest_branch status)

create_local_build_branch "$BRANCH_NAME"

UPDATED="no"

function perform_update() {
    echo "$BRANCH_NAME" | write_latest_branch status
    push_status_repo status
    UPDATED="yes"
}

if [ -z "$PREV_BRANCH" ]; then
    with_all_repos git push --tags --quiet build "$BRANCH_NAME"
    perform_update
else
    if ! print_updated_repos "$PREV_BRANCH" "$BRANCH_NAME" | diff -u /dev/null -; then
        with_all_repos git push --tags --quiet build "$BRANCH_NAME"
        perform_update
    fi
fi
