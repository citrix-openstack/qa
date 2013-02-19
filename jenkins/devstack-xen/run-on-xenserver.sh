#!/bin/bash
set -eu

XENSERVER_HOST="$1"
SCRIPT_TO_RUN="$2"

function on_xenserver
{
ssh -q -o Batchmode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$XENSERVER_HOST" bash -s -- "$@"
}

cat $SCRIPT_TO_RUN | on_xenserver
