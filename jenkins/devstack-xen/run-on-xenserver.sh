#!/bin/bash
set -eu

XENSERVER_HOST="$1"
SCRIPT_TO_RUN="$2"

function on_xenserver
{
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$XENSERVER_HOST" "$@"
}

cat $SCRIPT_TO_RUN | on_xenserver
