#!/bin/bash

#set -eux

. localrc

[ $DEBUG == "on" ] && set -x

rm -f "$FUEL_TEST_SUCCESS"
mkdir -p "$FUEL_TEST_LOG_DIR"

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

	if (/sbin/iptables -t nat -S | /bin/grep -q 192.168.111.0/24); then
		/sbin/iptables -t nat -D POSTROUTING -d 192.168.111.0/24 -j RETURN
	fi
	if (/sbin/iptables -t nat -S | /bin/grep -q 10.0.7.0/24); then
		/sbin/iptables -t nat -D POSTROUTING -d 10.0.7.0/24 -j RETURN
	fi
	if (/sbin/iptables -t nat -S | /bin/grep -q 10.1.7.0/24); then
		/sbin/iptables -t nat -D POSTROUTING -d 10.1.7.0/24 -j RETURN
	fi
	if (/sbin/iptables -t nat -S | /bin/grep -q 172.16.1.0/24); then
		/sbin/iptables -t nat -D POSTROUTING -s 172.16.1.0/24 ! -d 172.16.1.0/24 -j MASQUERADE
	fi

	crontab -l && crontab -r
	[ -f /root/rotate_xen_guest_logs.sh ] && rm /root/rotate_xen_guest_logs.sh

	yum list installed openstack-neutron-xen-plugins.noarch && yum remove openstack-neutron-xen-plugins.noarch -y
	yum list installed openstack-xen-plugins.noarch && yum remove openstack-xen-plugins.noarch -y
	yum list installed conntrack-tools.x86_64 && yum remove conntrack-tools.x86_64 -y

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
	for i in "${ALL_FUEL_VERSION[@]}"; do
		ssh -qo StrictHostKeyChecking=no root@$xs_host '[ -n "$(xe vm-list name-label=Fuel'$i' --minimal)" ] && xe vm-shutdown force=true vm="Fuel'$i'"'
	done
}

clear_xs "$XS_HOST"

exit 0