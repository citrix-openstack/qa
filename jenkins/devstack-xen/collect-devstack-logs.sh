#!/bin/bash
set -eux

thisdir=$(dirname $(readlink -f "$0"))

Server=$Server

rm -rf logs
for GUEST_NAME in DevStackComputeSlave DevStackOSDomU;
do
mkdir -p logs/$GUEST_NAME
(
cd logs/$GUEST_NAME
$thisdir/run-on-devstack.sh $Server $thisdir/on-domu-devstack-log-tgz-to-stdout.sh $GUEST_NAME | tar -xzf -
) && (cd logs; find -type f -exec ln -s {} \;) || rm -rf logs/$GUEST_NAME
done

