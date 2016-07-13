#!/bin/bash

set -eu

. localrc

[ $DEBUG == "on" ] && set -x

function create_networks {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	[ -z $(xe network-list name-label="'$2'" --minimal) ] && xe network-create name-label="'$2'"
	[ -z $(xe network-list name-label="'$3'" --minimal) ] && xe network-create name-label="'$3'"
	[ -z $(xe network-list name-label="'$4'" --minimal) ] && xe network-create name-label="'$4'"
	echo "Network created"
	'
}

function recreate_gateway {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	bridge=$(xe network-list name-label="'$2'" params=bridge minimal=true)
	recreate_gateway_sh="/etc/udev/scripts/recreate-gateway.sh"
	cat > $recreate_gateway_sh << RECREATE_GATEWAY
#!/bin/bash
/bin/sleep 10
if /sbin/ip link show $bridge > /dev/null 2>&1; then
  if !(/sbin/ip addr show $bridge | /bin/grep -q 172.16.1.1); then
    /sbin/ip addr add dev $bridge 172.16.1.1
  fi
  if !(/sbin/route -n | /bin/grep -q 172.16.1.0); then
    /sbin/route add -net 172.16.1.0 netmask 255.255.255.0 dev $bridge
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 192.168.111.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 192.168.111.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 10.0.7.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 10.0.7.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 10.1.7.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 10.1.7.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 172.16.1.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -s 172.16.1.0/24 ! -d 172.16.1.0/24 -j MASQUERADE
  fi
fi
RECREATE_GATEWAY

	chmod +x $recreate_gateway_sh
	# To skip the reboot, here explicitly run recreate-gateway.sh to activate for the first time
	$recreate_gateway_sh
	echo "SUBSYSTEM==net ACTION==add KERNEL==xapi* RUN+=$recreate_gateway_sh" > /etc/udev/rules.d/90-gateway.rules
	sed -i -e "s/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/" /etc/sysctl.conf
	sysctl net.ipv4.ip_forward=1
	'
}

function restore_fm {
	# Restore fuel master
	local xs_host="$1"
	local fm_name="$2"
	local fm_snapshot="$3"
	local fm_mnt="$4"
	local fm_xva="$5"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
	snapshot_uuid=$(xe snapshot-list name-label="'$fm_snapshot'" snapshot-of="$vm_uuid" --minimal)
	if [ -n "$snapshot_uuid" ]; then
		xe snapshot-revert snapshot-uuid="$snapshot_uuid"
	else
		mount "'$fm_mnt'" /mnt
		xe vm-import filename="/mnt/'$fm_xva'" preserve=true
		umount /mnt
		vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
		vif=$(xe vif-list vm-uuid=$vm_uuid device=1 --minimal)
		net=$(xe vif-list vm-uuid=$vm_uuid device=1 params=network-uuid --minimal)
		xe vif-destroy uuid=$vif
		mac=$(echo 00:60:2f$(od -txC -An -N3 /dev/random|tr \  :))
		xe vif-create vm-uuid="$vm_uuid" device=1 network-uuid="$net" mac=$mac
		xe vm-snapshot vm="'$fm_name'" new-name-label="'$fm_snapshot'"
	fi
	xe vm-start vm="'$fm_name'"
	'
}

function create_node {
	# Create a node server(compute/controller node) with given memory, disk and NICs
	local xs_host="$1"
	local vm="$2"
	local mem="$3"
	local disk="$4"

	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux

	vm="'$vm'"
	mem="'$mem'"
	disk="'$disk'"

	template="Other install media"

	vm_uuid=$(xe vm-install template="$template" new-name-label="$vm")

	localsr=$(xe pool-list params=default-SR --minimal)
	extra_vdi=$(xe vdi-create \
		name-label=xvdb \
		virtual-size="${disk}GiB" \
		sr-uuid=$localsr type=user)
	vbd_uuid=$(xe vbd-create vm-uuid=$vm_uuid vdi-uuid=$extra_vdi device=0)

	xe vm-memory-limits-set \
		static-min=${mem}MiB \
		static-max=${mem}MiB \
		dynamic-min=${mem}MiB \
		dynamic-max=${mem}MiB \
		uuid=$vm_uuid

	xe vm-param-set uuid=$vm_uuid HVM-boot-params:order=ndc
	'
}

function add_vif {
	local xs_host="$1"
	local vm="$2"
	local network="$3"
	local device="$4"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm="'$vm'"
	network="'$network'"
	device="'$device'"

	vm_uuid=$(xe vm-list name-label="'$vm'" --minimal)
	network=${network//Network /Pool-wide network associated with eth}
	network_uuid=$(xe network-list name-label="$network" --minimal)
	xe vif-create network-uuid=$network_uuid vm-uuid=$vm_uuid device=$device
	'
}

function add_himn {
	# Add HIMN to given compute node and return the Mac address of the added NIC
	local xs_host="$1"
	local vm="$2"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm="'$vm'"
	network=$(xe network-list bridge=xenapi minimal=true)
	vm_uuid=$(xe vm-list name-label="'$vm'" --minimal)

	vif=$(xe vif-list network-uuid=$network vm-uuid=$vm_uuid --minimal)
	if [ -z "$vif" ]; then
		vif=$(xe vif-create network-uuid=$network vm-uuid=$vm_uuid device=9 minimal=true)
	fi

	mac=$(xe vif-list uuid=$vif params=MAC --minimal)
	xe vm-param-set xenstore-data:vm-data/himn_mac=$mac uuid=$vm_uuid
	'
}

function wait_for_fm {
	# Wait for fuel master booting and return its IP address
	local xs_host="$1"
	local fm_name="$2"

	local fm_ip
	for i in {0..60}; do
		fm_networks=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
		'xe vm-list name-label="'$fm_name'" params=networks --minimal')
		fm_ip=$(echo $fm_networks | egrep -Eo "1/ip: ([0-9]+\.){3}[0-9]+")
		if [ -n "$fm_ip" ]; then
			echo ${fm_ip: 5}
			return
		fi
		sleep 10
	done
}

function start_node {
	# Boot up given node
	local xs_host="$1"
	local vm="$2"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'xe vm-start vm="'$vm'"'
}

function wait_for_nailgun {
	# Wait for nailgun service started until the fuel plugin can be installed
	local fm_ip="$1"

	local ready
	for i in {0..60}; do
		ready=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel plugins &> /dev/null
		echo $?
		')
		if [ "$ready" -eq 0 ]; then
			echo 1
			return
		fi
		sleep 10
	done
	echo 0
}

create_networks "$XS_HOST" "$NET1" "$NET2" "$NET3"

echo "Restoring Fuel Master.."
restore_fm "$XS_HOST" "$FM_NAME" "$FM_SNAPSHOT" "$FM_MNT" "$FM_XVA"

create_node "$XS_HOST" "Compute" "$NODE_MEM_COMPUTE" "$NODE_DISK"
add_vif "$XS_HOST" "Compute" "$NET1" 1
add_vif "$XS_HOST" "Compute" "$NET2" 2
add_vif "$XS_HOST" "Compute" "$NET3" 3
echo "Compute Node is created"
add_himn "$XS_HOST" "Compute"

echo "HIMN is added to Compute Node"
create_node "$XS_HOST" "Controller" "$NODE_MEM_CONTROLLER" "$NODE_DISK"
add_vif "$XS_HOST" "Controller" "$NET1" 1
add_vif "$XS_HOST" "Controller" "$NET2" 2
add_vif "$XS_HOST" "Controller" "$NET3" 3
echo "Controller Node is created"

FM_IP=$(wait_for_fm "$XS_HOST" "$FM_NAME")
[ -z "$FM_IP" ] && echo "Fuel Master IP obtaining timeout" && exit -1

sshpass -p "$FM_PWD" ssh-copy-id -o StrictHostKeyChecking=no root@$FM_IP

NAILGUN_READY=$(wait_for_nailgun "$FM_IP")
[ "$NAILGUN_READY" -eq 0 ] && echo "Nailgun test connection timeout" && exit -1

start_node "$XS_HOST" "Compute"
echo "Compute Node is started"
start_node "$XS_HOST" "Controller"
echo "Controller Node is started"

recreate_gateway "$XS_HOST" "$NET2"