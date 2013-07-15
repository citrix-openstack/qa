#!/bin/bash
set -eu

. lib/functions

assert_no_new_repos

BRANCH_NAME="build-$(date +%s)"

    
clone_status_repo "git://gold.eng.hq.xensource.com/git/internal/builds/status.git" status

pull_status_repo status

PREV_BRANCH=$(read_latest_branch status)

create_build_branch "$BRANCH_NAME"

if [ -z "$PREV_BRANCH" ]; then
    echo "$BRANCH_NAME" | write_latest_branch status
    push_status_repo status
else
    if ! print_updated_repos "$PREV_BRANCH" "$BRANCH_NAME" | diff -u /dev/null -; then
        echo "$BRANCH_NAME" | write_latest_branch status
        push_status_repo status
    fi
fi
