#!/bin/bash

set -eu

. lib/functions

assert_no_new_repos

ACTION="$@"

(
    cd .workspace
    with_all_repos "$@"
)
