#!/bin/bash

set -x

export XS_HOST="192.168.1.111"
export FM_NAME="Fuel7"
export ENV_NAME="TestEnv"
export REL_NAME="Kilo+Citrix XenServer on Ubuntu 14.04"
export FM_SNAPSHOT="MU1_applied"
export FUEL_PLUGIN_REFSPEC="refs/changes/47/272447/2"
export ATTRIBUTES_YAML="env_attributes.yaml"
export NETWORK_YAML="env_network.yaml"
export INTERFACE_YAML="node_interfaces.yaml"

function restore_fm {
	local xs_host="$1"
	local fm_name="$2"
	local fm_snapshot="$3"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -x
	#echo "FM_NAME : '$fm_name'"
	#echo "FM_SNAPSHOT : '$fm_snapshot'"
	vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
	#echo "VM_UUID : $vm_uuid"
	snapshot_uuid=$(xe snapshot-list name-label="'$fm_snapshot'" snapshot-of="$vm_uuid" --minimal)
	#echo "SNAPSHOT_UUID: $snapshot_uuid"
	xe snapshot-revert snapshot-uuid="$snapshot_uuid"
	xe vm-start vm="'$fm_name'"
	'
}

function wait_for_fm {
	local xs_host="$1"
	local fm_name="$2"
	local retry_count=$3
	local retry_interval=$4

	local fm_ip
	local counter=0
	while [ $counter -lt $retry_count ]; do
		fm_ip=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'eth1_ip=$(xe vm-list name-label="'$fm_name'" params=networks --minimal | egrep -Eo "1/ip: ([0-9]+\.){3}[0-9]+");echo ${eth1_ip: 5}')
		if [ -n "$fm_ip" ]; then
			eval "$5=$fm_ip"
			return
		fi
		let counter=counter+1
		echo "Fuel Master IP obtaining retry $counter"
		sleep $retry_interval
	done
}

function create_node {
	local xs_host="$1"
	local vm="$2"
	local mem="$3"
	local disk="$4"
	local eth0="$5"
	local eths=()
	for ((i=6;i<$#;i++)); do
		eths+=("\"${!i}\"")
	done
	local eth0_mac=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -x

	vm="'$vm'"
	mem="'$mem'"
	disk="'$disk'"
	eth0="'$eth0'"

	template="Other install media"
	device=0

	vm_uuid=$(xe vm-install template="$template" new-name-label="$vm")

	localsr=$(xe pool-list params=default-SR minimal=true)
	extra_vdi=$(xe vdi-create \
		name-label=xvdb \
		virtual-size="${disk}GiB" \
		sr-uuid=$localsr type=user)
	vbd_uuid=$(xe vbd-create vm-uuid=$vm_uuid vdi-uuid=$extra_vdi device=$device)
	xe vm-cd-add vm=$vm_uuid device=1 cd-name="xs-tools.iso"

	xe vm-memory-limits-set \
		static-min=${mem}MiB \
		static-max=${mem}MiB \
		dynamic-min=${mem}MiB \
		dynamic-max=${mem}MiB \
		uuid=$vm_uuid

	vif0=$(xe vif-create network-uuid=$(xe network-list name-label="$eth0" --minimal) vm-uuid=$vm_uuid device=0)
	eth0_mac=$(xe vif-param-get uuid=$vif0 param-name=MAC)
	echo "${eth0_mac:12:5}"

	for eth in '${eths[@]}'; do
		device=$(($device + 1))
		eth=${eth//Network /Pool-wide network associated with eth}
		vif=$(xe vif-create network-uuid=$(xe network-list name-label="$eth" --minimal) vm-uuid=$vm_uuid device=$device)
	done

	xe vm-param-set uuid=$vm_uuid HVM-boot-params:order=ndc
	')
	eval "${!#}=$eth0_mac"
}

function start_node {
	local xs_host="$1"
	local vm="$2"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -x

	vm="'$vm'"
	xe vm-start vm=$vm
	'
}

function add_himn {
	local xs_host="$1"
	local vm="$2"
	local himn_mac=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -x
	vm="'$vm'"
	network=$(xe network-list bridge=xenapi minimal=true)
	vm_uuid=$(xe vm-list name-label="'$vm'" --minimal)

	vif=$(xe vif-list network-uuid=$network vm-uuid=$vm_uuid --minimal)
	if [ -z $vif ]; then
		vif=$(xe vif-create network-uuid=$network vm-uuid=$vm_uuid device=9 minimal=true)
	fi

	xe vm-start vm=$vm
	mac=$(xe vif-list uuid=$vif params=MAC --minimal)
	dom_id=$(xe vm-list params=dom-id uuid=$vm_uuid --minimal)
	xenstore-write /local/domain/$dom_id/vm-data/himn_mac $mac
	echo $mac
	')
	eval "$3=$himn_mac"
}

function build_plugin {
	local fm_ip="$1"
	local refspec="$2"
	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
set -x
pip install virtualenv
cd /root/
virtualenv fuel-devops-venv
. fuel-devops-venv/bin/activate
pip install fuel-plugin-builder
yum install git createrepo dpkg-devel dpkg-dev rpm rpm-build -y
git clone https://review.openstack.org/openstack/fuel-plugin-xenserver
cd fuel-plugin-xenserver
git fetch https://review.openstack.org/openstack/fuel-plugin-xenserver '"$refspec"'
git checkout FETCH_HEAD
fpb --check .
fpb --build .
	'
}

function wait_for_nailgun {
	local fm_ip="$1"
	local retry_count=$2
	local retry_interval=$3
	local nailgun_ready="$4"

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
			eval "$nailgun_ready=1"
			return
		fi
		let counter=counter+1
		echo "Nailgun test retry $counter"
		sleep $retry_interval
	done
	eval "$nailgun_ready=0"
}

function install_plugin {
	local fm_ip="$1"

	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
	set -x
	export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
	fuel plugins --install /root/fuel-plugin-xenserver/fuel-plugin-xenserver-2.0-2.0.0-1.noarch.rpm &> /dev/null
	'
}

function create_env {
	local fm_ip="$1"
	local env_name="$2"
	local rel_name="$3"
	local attributes_yaml="$4"
	local network_yaml="$5"

	scp $attributes_yaml root@$fm_ip:/tmp/
	scp $network_yaml root@$fm_ip:/tmp/
	scp "yaml_overwrite.py" root@$fm_ip:/tmp/
	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
	set -x
	export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"

	rel_id=$(fuel rel | grep "'$rel_name'" | egrep ^[0-9]+ -o)
	env_id=$(fuel env -c --name "'$env_name'" --rel $rel_id -n nova --nst vlan --yaml | grep ^id: | egrep [0-9]+ -o)

	cd /tmp/

	fuel env --env $env_id --attributes -d
	./yaml_overwrite.py "'$attributes_yaml'" cluster_$env_id/attributes.yaml
	fuel env --env $env_id --attributes -u

	fuel network --env $env_id -d
	./yaml_overwrite.py "'$network_yaml'" network_$env_id.yaml
	fuel network --env $env_id -u
	'
}

function wait_for_node {
	local fm_ip="$1"
	local node_mac="$2"
	local retry_count=$3
	local retry_interval=$4

	local counter=0
	local discovered
	while [ $counter -lt $retry_count ]; do
		discovered=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel node | grep "'$node_mac'" -q
		echo $?
		')
		if [ $discovered -eq 0 ]; then
			eval "$5=1"
			return
		fi
		let counter=counter+1
		echo "Node discovery retry $counter"
		sleep $retry_interval
	done
	eval "$5=0"
}

function add_env_node {
	local fm_ip="$1"
	local env_name="$2"
	local node_mac="$3"
	local role="$4"
	local interface_yaml="$5"

	scp configure_interfaces.py root@$fm_ip:/tmp/
	scp $interface_yaml root@$fm_ip:/tmp/
	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	node_id=$(fuel node --node-id "'$node_mac'" | grep "'$node_mac'" | egrep -o "^[0-9]+")
	fuel node set --node $node_id --env $env_id --role "'$role'"

	cd /tmp
	fuel node --node-id $node_id --net -d
	./configure_interfaces.py node_$node_id/interfaces.yaml '$interface_yaml'
	fuel node --node-id $node_id --net -u
	'
}

function verify_network {
	local fm_ip="$1"
	local env_name="$2"
	local retry_count=$3
	local retry_interval=$4

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel network --verify --env $env_id
	'

	local counter=0
	local ok
	while [ $counter -lt $retry_count ]; do
		task=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel task | grep verify_networks
		')
		status=$(echo $task | awk -F '|' '{print $2}')
		progress=$(echo $task | awk -F '|' '{print $5}')
		if [ $status -eq "error" ]; then
			eval "$5=0"
			return
		fi
		if [ $progress -eq "100" ]; then
			eval "$5=1"
			return
		fi
		let counter=counter+1
		echo "Network verification retry $counter"
		sleep $retry_interval
	done
	eval "$5=0"
}

function deploy_env {
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel --env $env_id health --check smoke,sanity,tests_platform,cloudvalidation
	'
}

function health_check {
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel deploy-changes --env $env_id
	'
}

echo "Restoring Fuel Master.."
restore_fm "$XS_HOST" "$FM_NAME" "$FM_SNAPSHOT"

wait_for_fm "$XS_HOST" "$FM_NAME" 10 60 "FM_IP"
[ -z $FM_IP ] && echo "Fuel Master IP obtaining timeout" && exit -1

create_node "$XS_HOST" "Compute" 3072 60 pxe "Network 1" "br100" "COMPUTE_MAC"
echo "Compute Node is created"
add_himn "$XS_HOST" "Compute" "HIMN_MAC"
echo "HIMN is added to Compute Node"
create_node "$XS_HOST" "Controller" 3072 60 pxe "Network 1" "br100" "CONTROLLER_MAC"
echo "Controller Node is created"

build_plugin $FM_IP $FUEL_PLUGIN_REFSPEC
echo "Fuel plugin with $FUEL_PLUGIN_REFSPEC is built"

wait_for_nailgun "$FM_IP" 20 60 "NAILGUN_READY"
[ $NAILGUN_READY -eq 0 ] && echo "Nailgun test connection timeout" && exit -1

install_plugin "$FM_IP"
echo "Fuel plugin is installed"

create_env "$FM_IP" "$ENV_NAME" "$REL_NAME" "$ATTRIBUTES_YAML" "$NETWORK_YAML"

start_node "$XS_HOST" "Compute"
echo "Compute Node is started"
start_node "$XS_HOST" "Controller"
echo "Controller Node is started"

wait_for_node "$FM_IP" "$COMPUTE_MAC" 10 60 "COMPUTE_DISCOVERED"
[ -z $COMPUTE_DISCOVERED ] && echo "Compute node discovery timeout" && exit -1
add_env_node "$FM_IP" "$ENV_NAME" "$COMPUTE_MAC" "compute,cinder" $INTERFACE_YAML
echo "Compute Node added"

wait_for_node "$FM_IP" "$CONTROLLER_MAC" 10 60 "CONTROLLER_DISCOVERED"
[ -z $CONTROLLER_DISCOVERED ] && echo "Controller node discovery timeout" && exit -1
add_env_node "$FM_IP" "$ENV_NAME" "$CONTROLLER_MAC" "controller" $INTERFACE_YAML
echo "Controller Node added"

verify_network "$FM_IP" "$ENV_NAME" 10 60 "NETWORK_VERIFIED"
[ -z $NETWORK_VERIFIED ] && echo "Network verification failed" && exit -1

deploy_env "$FM_IP" "$ENV_NAME"
health_check "$FM_IP" "$ENV_NAME"
