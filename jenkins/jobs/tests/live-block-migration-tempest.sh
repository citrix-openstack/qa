#!/bin/bash
set -exu

cd tempest
sed -i \
-e 's/^live_migration_available.*/live_migration_available = True/g' \
-e 's/^use_block_migration_for_live_migration.*/use_block_migration_for_live_migration = True/g' \
etc/tempest.conf

nosetests tempest/tests/compute/test_live_block_migration.py
