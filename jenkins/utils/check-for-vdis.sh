#!/bin/sh

set -eux

thisdir=$(dirname "$0")
. "$thisdir/common-xe.sh"

c1=$(xe_min vdi-list params=name-label other-config= | grep instance | wc -l)
c2=$(xe_min vdi-list params=name-label other-config= | grep Glance | wc -l)

echo $(($c1+$c2))
