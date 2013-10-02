#!/bin/bash
set -eu

USERNAME="$1"
PASSWORD="$2"

THISDIR="$(pwd)"

. lib/functions

assert_no_new_repos

(
    set -eu
    mkdir -p .workspace
    cd .workspace
    generate_repos | while read repo; do
        repo_to_be_created=$(repo_name "$repo" | cut -d "." -f 1)
        [ -n "$repo_to_be_created" ]
        echo "Dealing with $repo_to_be_created"
        python "$THISDIR/create-github-repo.py" "$USERNAME" "$PASSWORD" "citrix-openstack" "build-$repo_to_be_created"
    done
)
