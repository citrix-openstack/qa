#!/bin/bash

set -eux

. lib/functions

assert_no_new_repos

ACTION="$@"

(
    cd .workspace
    set +e
    with_all_repos "$@"
)
