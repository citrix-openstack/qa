#!/bin/bash

set -eu

. localrc

[ $DEBUG == "on" ] && set -x

function get_fm_ip {
	# Wait for fuel master booting and return its IP address
	local xs_host="$1"
	local fm_name="$2"

	fm_networks=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'xe vm-list name-label="'$fm_name'" params=networks --minimal')
	fm_ip=$(echo $fm_networks | egrep -Eo "1/ip: ([0-9]+\.){3}[0-9]+")

	echo ${fm_ip: 5}
}

function build_plugin {
	# Build plugin with given refspec
	# refspec can be empty
	local fm_ip="$1"
	local refspec="${2:-''}"
	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
set -ex

yum install python-pip git createrepo dpkg-devel dpkg-dev rpm rpm-build -y

pip install virtualenv
cd /root/
if [[ ! -d "fuel-devops-venv" ]]; then
	virtualenv fuel-devops-venv
fi
. fuel-devops-venv/bin/activate

pip install git+https://github.com/openstack/fuel-plugins

if [[ ! -d "fuel-plugin-xenserver" ]]; then
	git clone https://review.openstack.org/openstack/fuel-plugin-xenserver
fi
cd fuel-plugin-xenserver
git fetch https://review.openstack.org/openstack/fuel-plugin-xenserver '"$refspec"'
git checkout FETCH_HEAD
fpb --check .
fpb --build .
	'
}

function install_plugin {
	local fm_ip="$1"

	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
	set -eux
	export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
	fuel plugins --install $(ls /root/fuel-plugin-xenserver/fuel-plugin-xenserver-*.noarch.rpm -t | head -n 1) &> /dev/null
	'
}

function create_env {
	# Create a cluster with given name and release.
	# Metadata in attributes_yaml and network_yaml will be used
	# to overwrite the default value in nailgun
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
	set -eux
	export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"

	rel_id=$(fuel rel | grep "'$rel_name'" | egrep ^[0-9]+ -o)
	env_id=$(fuel env -c --name "'$env_name'" --rel $rel_id --yaml | grep ^id: | egrep [0-9]+ -o)

	cd /tmp/

	fuel env --env $env_id --attributes -d
	./yaml_overwrite.py "'$attributes_yaml'" cluster_$env_id/attributes.yaml
	fuel env --env $env_id --attributes -u

	fuel network --env $env_id -d
	./yaml_overwrite.py "'$network_yaml'" network_$env_id.yaml
	fuel network --env $env_id -u
	'
}


function get_node_mac {
	# Return its shortened node's PXE MAC address
	local xs_host="$1"
	local vm="$2"
	local eth0_mac=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux

	vm="'$vm'"
	vm_uuid=$(xe vm-list name-label="$vm" --minimal)
	network_uuid=$(xe network-list name-label=pxe --minimal)
	eth0_mac=$(xe vif-list network-uuid=$network_uuid vm-uuid=$vm_uuid params=MAC --minimal)
	echo "${eth0_mac:12:5}"
	')
	echo $eth0_mac
}

function wait_for_node {
	# Wait for node discovery
	local fm_ip="$1"
	local node_mac="$2"
	local retry_count=$3
	local retry_interval=$4

	local counter=0
	local discovered
	while [ $counter -lt $retry_count ]; do
		discovered=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		set -eux

		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel node | grep "'$node_mac'" -q
		echo $?
		')
		if [ $discovered -eq 0 ]; then
			echo 1
			return
		fi
		let counter=counter+1
		sleep $retry_interval
	done
	echo 0
}

function add_env_node {
	# Add node to a given cluster
	# interface_yaml abstracts the node's network configuraion
	local fm_ip="$1"
	local env_name="$2"
	local node_mac="$3"
	local role="$4"
	local interface_yaml="$5"

	scp configure_interfaces.py root@$fm_ip:/tmp/
	scp $interface_yaml root@$fm_ip:/tmp/
	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux

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
	# Do network verification and wait for result
	# return 1 when passes, return 0 when failed or retrial timeout
	local fm_ip="$1"
	local env_name="$2"
	local retry_count=$3
	local retry_interval=$4

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux

	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel network --verify --env $env_id &> /dev/null
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
		if [ $status == "error" ]; then
			echo 0
			return
		fi
		if [ $progress -eq "100" ]; then
			echo 1
			return
		fi
		let counter=counter+1
		sleep $retry_interval
	done
	echo 0
}

function deploy_env {
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux

	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel deploy-changes --env $env_id
	'
}

FM_IP=$(get_fm_ip "$XS_HOST" "$FM_NAME")

build_plugin $FM_IP $FUEL_PLUGIN_REFSPEC
echo "Fuel plugin with $FUEL_PLUGIN_REFSPEC is built"

install_plugin "$FM_IP"
echo "Fuel plugin is installed"

create_env "$FM_IP" "$ENV_NAME" "$REL_NAME" "$ATTRIBUTES_YAML" "$NETWORK_YAML"

COMPUTE_MAC=$(get_node_mac "$XS_HOST" "Compute")
[ -z $COMPUTE_MAC ] && echo "Compute node doesnot exist" && exit -1
COMPUTE_DISCOVERED=$(wait_for_node "$FM_IP" "$COMPUTE_MAC" 60 10)
[ -z $COMPUTE_DISCOVERED ] && echo "Compute node discovery timeout" && exit -1
add_env_node "$FM_IP" "$ENV_NAME" "$COMPUTE_MAC" "compute,cinder" $INTERFACE_YAML
echo "Compute Node added"

CONTROLLER_MAC=$(get_node_mac "$XS_HOST" "Controller")
[ -z $CONTROLLER_MAC ] && echo "Controller node doesnot exist" && exit -1
CONTROLLER_DISCOVERED=$(wait_for_node "$FM_IP" "$CONTROLLER_MAC" 60 10)
[ -z $CONTROLLER_DISCOVERED ] && echo "Controller node discovery timeout" && exit -1
add_env_node "$FM_IP" "$ENV_NAME" "$CONTROLLER_MAC" "controller" $INTERFACE_YAML
echo "Controller Node added"

NETWORK_VERIFIED=$(verify_network "$FM_IP" "$ENV_NAME" 60 10)
[ $NETWORK_VERIFIED -eq 0 ] && echo "Network verification failed" && exit -1

deploy_env "$FM_IP" "$ENV_NAME"
