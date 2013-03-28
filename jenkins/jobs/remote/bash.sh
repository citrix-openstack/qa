#!/bin/bash

set -eux

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVER SCRIPT [script parameters]

Run a specific script, using bash, on a remote server

positional arguments:
 SERVER     A string, used to ssh to the server (e.g.:user@host)
 SCRIPT     A script, that could be interpreted with bash. Will run on SERVER
EOF
exit 1
}

SERVER="${1-$(print_usage_and_die)}"
SCRIPT="${2-$(print_usage_and_die)}"
shift 2

cat "$SCRIPT" |
ssh -q \
    -o Batchmode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$SERVER" bash -s -- "$@"
