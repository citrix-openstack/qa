#!/bin/bash
set -exu

cd tempest

# Apply the patch
#git fetch https://review.openstack.org/openstack/tempest refs/changes/09/25609/1 && git cherry-pick FETCH_HEAD || true
git fetch https://review.openstack.org/openstack/tempest refs/changes/09/25609/3 && git cherry-pick FETCH_HEAD || true

sed -i \
-e 's/^live_migration_available.*/live_migration_available = True/g' \
-e 's/^use_block_migration_for_live_migration.*/use_block_migration_for_live_migration = True/g' \
etc/tempest.conf

nosetests tempest/tests/compute/test_live_block_migration.py
