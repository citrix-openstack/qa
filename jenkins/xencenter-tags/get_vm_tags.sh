#!/bin/sh

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

echo $(xe_min vm-list params=tags)
