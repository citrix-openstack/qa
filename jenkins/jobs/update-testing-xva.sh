#!/bin/bash

set -eux

OPENSTACK_XENAPI_TESTING_XVA_URL="$1"
REVISION="$2"
UPLOAD_IMAGE="${UPLOAD_IMAGE:-NO}"


eval $(ssh-agent)

function finish {
    ssh-agent -k
}
trap finish EXIT

ssh-add

for dependency in worker-vms remote-bash; do
    rm -rf $dependency
    git clone https://github.com/citrix-openstack/$dependency

    export PATH=$PATH:$(pwd)/$dependency/bin
done

rm -rf src
git clone $OPENSTACK_XENAPI_TESTING_XVA_URL src
cd src
git checkout $REVISION

UPLOAD_IMAGE="$UPLOAD_IMAGE" bin/cloud-xva-create "$REVISION"
