#!/bin/bash

set -eux

OPENSTACK_XENAPI_TESTING_XVA_URL="$1"
OPENSTACK_XENAPI_TESTING_XVA_BRANCH="$2"


[ -n "$PublicHttpServerUserAndHost" ]
[ -n "$PublicHttpServerOpenStackPath" ]
[ -n "$PrivateKeyToPublicHttpServer" ]

eval $(ssh-agent) || { ssh-agent -k; exit 1; }
ssh-add "$PrivateKeyToPublicHttpServer" || { ssh-agent -k; exit 1; }

{
    for dependency in worker-vms remote-bash; do
        rm -rf $dependency
        git clone https://github.com/citrix-openstack/$dependency

        export PATH=$PATH:$(pwd)/$dependency/bin
    done

    rm -rf "openstack-xenapi-testing-xva"
    git clone "$OPENSTACK_XENAPI_TESTING_XVA_URL" -b "$OPENSTACK_XENAPI_TESTING_XVA_BRANCH"

    cd openstack-xenapi-testing-xva

    bin/cloud-xva-create "OPENSTACK_XENAPI_TESTING_XVA_BRANCH"
    ssh-agent -k
} || { ssh-agent -k; exit 1; }
