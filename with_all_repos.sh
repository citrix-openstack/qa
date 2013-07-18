#!/bin/bash

set -eux

. lib/functions

ACTION="$@"

(
    cd .workspace
    with_all_repos "$@"
)
