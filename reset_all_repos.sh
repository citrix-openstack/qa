#!/bin/bash

set -eu

. lib/functions

assert_no_new_repos

(
    cd .workspace
    reset_repos
)
