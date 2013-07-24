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

if [ -z "$PREV_BRANCH" ]; then
    with_all_repos git push --tags --quiet build "$BRANCH_NAME"
    echo "$BRANCH_NAME" | write_latest_branch status
    push_status_repo status
    UPDATED="yes"
else
    if ! print_updated_repos "$PREV_BRANCH" "$BRANCH_NAME" | diff -u /dev/null -; then
        with_all_repos git push --tags --quiet build "$BRANCH_NAME"
        echo "$BRANCH_NAME" | write_latest_branch status
        push_status_repo status
        UPDATED="yes"
    fi
fi


if [ "$UPDATED" == "yes" ]; then
    CITRIX_BRANCH_NAME="ctx-$(date +%s)"
    create_local_build_branch "$CITRIX_BRANCH_NAME"
    cd NOVA_REPO
    git fetch https://review.openstack.org/openstack/nova refs/changes/41/38441/1 && git cherry-pick FETCH_HEAD
    cd ..
    cd DEVSTACK_REPO
    git fetch https://review.openstack.org/openstack-dev/devstack refs/changes/44/38444/3 && git cherry-pick FETCH_HEAD
    cd ..
    with_all_repos git push --tags --quiet build "$CITRIX_BRANCH_NAME"
else
    echo "No changes detected since last run"
fi
