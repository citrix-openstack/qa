#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVER [script parameters]

Read a bash script on the standard input, and execute it on the remote system.


positional arguments:
 SERVER     A string, used to ssh to the server (e.g.:user@host)
EOF
exit 1
}

SERVER="${1-$(print_usage_and_die)}"
shift

ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$SERVER" bash -s -- "$@"
