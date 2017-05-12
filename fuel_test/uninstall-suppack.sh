#!/bin/bash

set -x

function wait_toolstack_ready {
    while ! ls /var/run/xapi_init_complete.cookie; do
        sleep 2
    done
}

function version_ge() {
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1";
}


ELY_VER=2.2.0
host_uuid=$(xe host-list --minimal)
xcp_ver=$(xe host-param-get param-name=software-version param-key=platform_version uuid=$host_uuid)

if version_ge $xcp_ver $ELY_VER; then
    # Find openstack-xenapi-plugins suppack update uuid
    update_uuids=$(xe update-list name-label=openstack-xenapi-plugins --minimal)
    if [ -z "$update_uuids" ]; then
        exit 0
    fi

    # Find the correct package and uninstall them
    yum list installed openstack-neutron-xen-plugins.noarch && yum remove openstack-neutron-xen-plugins.noarch -y
    yum list installed openstack-xen-plugins.noarch && yum remove openstack-xen-plugins.noarch -y
    yum list installed conntrack-tools.x86_64 && yum remove conntrack-tools.x86_64 -y

    # remove updates
    update_uuids=${update_uuids//,/ }
    for uuid in $update_uuids
    do
        if [ -n "$uuid" ]; then
            # Remove uuid related folder/file and restart toolstack
            rm -rf /var/update/applied/$uuid
            rm -f /var/run/xapi_init_complete.cookie
            xe-toolstack-restart
            wait_toolstack_ready

            # Destroy the unapplied update and restart toolstack
            xe update-destroy uuid=$uuid
            rm -f /var/run/xapi_init_complete.cookie
            xe-toolstack-restart
            wait_toolstack_ready
        fi
    done
else
    # Find the correct package and uninstall them
    yum list installed openstack-neutron-xen-plugins.noarch && yum remove openstack-neutron-xen-plugins.noarch -y
    yum list installed openstack-xen-plugins.noarch && yum remove openstack-xen-plugins.noarch -y
    yum list installed conntrack-tools.x86_64 && yum remove conntrack-tools.x86_64 -y
fi

