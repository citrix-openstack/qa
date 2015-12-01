#!/bin/bash

set -eu

. lib/functions

assert_no_new_repos

REPOS="$1"
shift
ACTION="$@"

(
    cd .workspace
    with_some_repos "$REPOS" "$ACTION"
)
