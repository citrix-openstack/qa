#!/bin/bash
set -eux

cd /opt/stack/devstack/exercises
./floating_ips.sh
./aggregates.sh
./euca.sh
