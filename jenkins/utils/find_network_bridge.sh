#!/bin/sh

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

network_attr="$1"

bridge=$(get_network_bridge "$network_attr")
echo $bridge