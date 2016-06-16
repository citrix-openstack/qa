#!/bin/bash

#set -eux

. localrc

[ $DEBUG == "on" ] && set -x

function clear_xs {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux

	route -n | grep 192.168.0.0 -q && \
		route del -net 192.168.0.0 gw 169.254.0.2 netmask 255.255.255.0 dev xenapi
	route -n | grep 192.168.1.0 -q && \
		route del -net 192.168.1.0 gw 169.254.0.2 netmask 255.255.255.0 dev xenapi
	> /etc/sysconfig/static-routes

	crontab -l && crontab -r
	[ -f /root/rotate_xen_guest_logs.sh ] && rm /root/rotate_xen_guest_logs.sh

	yum list installed openstack-neutron-xen-plugins.noarch && yum remove openstack-neutron-xen-plugins.noarch -y
	yum list installed openstack-xen-plugins.noarch && yum remove openstack-xen-plugins.noarch -y

	COMPUTE_UUID=$(xe vm-list name-label=Compute --minimal)
	[ -n "$COMPUTE_UUID" ] && xe vm-shutdown force=true uuid=$COMPUTE_UUID
	[ -n "$COMPUTE_UUID" ] && xe vm-destroy uuid=$COMPUTE_UUID
	CONTROLLER_UUID=$(xe vm-list name-label=Controller --minimal)
	[ -n "$COMPUTE_UUID" ] && xe vm-shutdown force=true uuid=$CONTROLLER_UUID
	[ -n "$COMPUTE_UUID" ] && xe vm-destroy uuid=$CONTROLLER_UUID
	'
}

clear_xs "$XS_HOST"