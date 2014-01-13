#!/bin/bash

set -eux

[ -n "$PublicHttpServerUserAndHost" ]
[ -n "$PublicHttpServerOpenStackPath" ]
[ -n "$PrivateKeyToPublicHttpServer" ]

eval $(ssh-agent) || { ssh-agent -k; exit 1; }
ssh-add "$PrivateKeyToPublicHttpServer" || { ssh-agent -k; exit 1; }

{
    for dependency in worker-vms remote-bash; do
        [ -e $dependency ] \
        && ( cd $dependency; git pull ) \
        || git clone https://github.com/citrix-openstack/$dependency

        export PATH=$PATH:$(pwd)/$dependency/bin
    done

    [ -e "openstack-xenapi-testing-xva" ] \
        && ( cd openstack-xenapi-testing-xva; git pull ) \
        || git clone https://github.com/citrix-openstack/openstack-xenapi-testing-xva

    cd openstack-xenapi-testing-xva

    bin/cloud-xva-create
    ssh-agent -k
} || { ssh-agent -k; exit 1; }
