#!/bin/bash
set -eux

rm -rf infra
hg clone http://hg.uk.xensource.com/openstack/infrastructure.hg/ infra

cd infra/osci

./ssh.sh prod_ci ls -la
