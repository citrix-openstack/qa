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

	COMPUTE_UUIDS=$(xe vm-list name-label=Compute --minimal)
	for uuid in $(echo $COMPUTE_UUIDS | sed "s/,/ /g")
	do
		power_state=$(xe vm-list params=power-state uuid=$uuid --minimal)
		[ $power_state == "running" ] && xe vm-shutdown force=true uuid=$uuid
		vbd=$(xe vbd-list vm-uuid=$uuid type=Disk params=uuid --minimal)
		[ -n "$vbd" ] && xe vbd-param-set uuid=$vbd other-config:owner
		xe vm-uninstall uuid=$uuid force=true
	done
	CONTROLLER_UUIDS=$(xe vm-list name-label=Controller --minimal)
	for uuid in $(echo $CONTROLLER_UUIDS | sed "s/,/ /g")
	do
		power_state=$(xe vm-list params=power-state uuid=$uuid --minimal)
		[ $power_state == "running" ] && xe vm-shutdown force=true uuid=$uuid
		vbd=$(xe vbd-list vm-uuid=$uuid type=Disk params=uuid --minimal)
		[ -n "$vbd" ] && xe vbd-param-set uuid=$vbd other-config:owner
		xe vm-uninstall uuid=$uuid force=true
	done
	'
}

clear_xs "$XS_HOST"