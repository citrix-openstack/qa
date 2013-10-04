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
    generate_repos | python "$THISDIR/create-github-repo.py" "$USERNAME" "$PASSWORD"
)
