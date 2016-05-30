#!/bin/bash

set -eu

. localrc

[ $DEBUG == "on" ] && set -x

function restore_fm {
	#Restore snapshot that has test machine's ssh public key
	local xs_host="$1"
	local fm_name="$2"
	local fm_snapshot="$3"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
	snapshot_uuid=$(xe snapshot-list name-label="'$fm_snapshot'" snapshot-of="$vm_uuid" --minimal)
	xe snapshot-revert snapshot-uuid="$snapshot_uuid"
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
	if [ -z $vif ]; then
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
	local retry_count=$3
	local retry_interval=$4

	local fm_ip
	local counter=0
	while [ $counter -lt $retry_count ]; do
		fm_networks=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
		'xe vm-list name-label="'$fm_name'" params=networks --minimal')
		fm_ip=$(echo $fm_networks | egrep -Eo "1/ip: ([0-9]+\.){3}[0-9]+")
		if [ -n "$fm_ip" ]; then
			echo ${fm_ip: 5}
			return
		fi
		let counter=counter+1
		sleep $retry_interval
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
	local retry_count=$2
	local retry_interval=$3

	local counter=0
	local ready
	while [ $counter -lt $retry_count ]; do
		ready=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel plugins &> /dev/null
		echo $?
		')
		if [ $ready -eq 0 ]; then
			echo 1
			return
		fi
		let counter=counter+1
		sleep $retry_interval
	done
	echo 0
}

echo "Restoring Fuel Master.."
restore_fm "$XS_HOST" "$FM_NAME" "$FM_SNAPSHOT"

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

FM_IP=$(wait_for_fm "$XS_HOST" "$FM_NAME" 60 10)
[ -z $FM_IP ] && echo "Fuel Master IP obtaining timeout" && exit -1

NAILGUN_READY=$(wait_for_nailgun "$FM_IP" 60 10)
[ $NAILGUN_READY -eq 0 ] && echo "Nailgun test connection timeout" && exit -1

start_node "$XS_HOST" "Compute"
echo "Compute Node is started"
start_node "$XS_HOST" "Controller"
echo "Controller Node is started"