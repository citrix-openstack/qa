#!/bin/bash

set -eux

OPENSTACK_XENAPI_TESTING_XVA_URL="$1"
REVISION="$2"
REVISION_TYPE="${3:-RELEASE}"


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

    rm -rf openstack-xenapi-testing-xva*
    if [ "$REVISION_TYPE" == "RELEASE" ]; then
	wget -qO - "$OPENSTACK_XENAPI_TESTING_XVA_URL/archive/${REVISION}.tar.gz" | tar -xzf -
    else
	git clone $OPENSTACK_XENAPI_TESTING_XVA_URL openstack-xenapi-testing-xva-$REVISION
	git checkout $REVISION
    fi

    cd openstack-xenapi-testing-xva*

    bin/cloud-xva-create "$REVISION"
    ssh-agent -k
} || { ssh-agent -k; exit 1; }
