#!/bin/bash
set -eux

PARAMS="$1"

ssh guard@silicon lock-get-single-server > "${PARAMS}"
