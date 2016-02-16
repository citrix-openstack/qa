#!/bin/bash

set +eux

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
	xe vm-cd-add vm=$vm_uuid device=1 cd-name="xs-tools.iso"

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


echo "Restoring Fuel Master.."
restore_fm "$XS_HOST" "$FM_NAME" "$FM_SNAPSHOT"

create_node "$XS_HOST" "Compute" 3072 60
add_vif "$XS_HOST" "Compute" pxe 1
add_vif "$XS_HOST" "Compute" "Network 1" 2
add_vif "$XS_HOST" "Compute" br100 3
echo "Compute Node is created"
add_himn "$XS_HOST" "Compute"

echo "HIMN is added to Compute Node"
create_node "$XS_HOST" "Controller" 3072 60
add_vif "$XS_HOST" "Controller" pxe 1
add_vif "$XS_HOST" "Controller" "Network 1" 2
add_vif "$XS_HOST" "Controller" br100 3
echo "Controller Node is created"
