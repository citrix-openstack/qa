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
	local fuel_version="$2"
	local refspec="${3:-''}"

	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
set -ex

yum install python-pip git createrepo dpkg-devel dpkg-dev rpm rpm-build -y

# install RPMs for building supplemental packages
yum install -y --enablerepo=base expect rpm-sign libarchive

cd /root/

if [[ ! -d "fuel-plugin-xenserver" ]]; then
	git clone '${REPO_URL}'/openstack/fuel-plugin-xenserver -b '${REPO_BRANCH}'
fi
cd fuel-plugin-xenserver
git fetch '${FETCH_URL}'/openstack/fuel-plugin-xenserver '"$refspec"'
git checkout FETCH_HEAD

pip install git+https://github.com/openstack/fuel-plugins
	'

	if [ "$fuel_version" -eq 8 ]; then
		ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
set -ex
cd /root/fuel-plugin-xenserver
wget "'$GPG_KEYFILE_URL'" -O /root/fuel-plugin-xenserver/suppack/RPM-GPG-KEY-XS-OPENSTACK
fpb --check .
fpb --build .
mkdir -p output
mv *.noarch.rpm output/

		'
	else
		if [ -f branding.inc ]; then
			scp branding.inc root@$fm_ip:/root/fuel-plugin-xenserver
		fi
		ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
set -ex
cd /root/fuel-plugin-xenserver
pip install bandit
bandit deployment_scripts/compute_post_deployment.py
make clean
make rpm
		'
	fi

}

function install_plugin {
	local fm_ip="$1"

	ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
	set -eux
	export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
	fuel plugins --install $(ls /root/fuel-plugin-xenserver/output/*.noarch.rpm -t | head -n 1) &> /dev/null
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
	for i in {0..200..10}; do
		set +x
		discovered=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		set -ux

		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel node | grep "'$node_mac'" -q
		echo $?
		')
		set -x
		[ "$discovered" -eq 0 ] && echo true && return
		sleep 10
	done
}

function wait_for_node_reboot_and_retry {
	local fm_ip="$1"
	local node_mac="$2"
	local xs_host="$3"
	local vm="$4"

	local discovered
	for i in {0..10}; do
		discovered=$(wait_for_node $fm_ip $node_mac)
		[ -n "$discovered" ] && echo $discovered && return
		ssh -qo StrictHostKeyChecking=no root@$xs_host '
		power_state=$(xe vm-list name-label="'$vm'" params=power-state --minimal)
		if [ "$power_state" == "running" ]; then
			xe vm-reboot vm="'$vm'" force=true
		else
			xe vm-start vm="'$vm'" force=true
		fi
		'
	done
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
	node_id=$(fuel node --node-id "'$node_mac'" | grep "'$node_mac'" | awk -F "|" "{print \$1}" | tr -d " ")
	fuel node set --node $node_id --env $env_id --role "'$role'"

	cd /tmp
	fuel node --node-id $node_id --net -d
	./configure_interfaces.py node_$node_id/interfaces.yaml '$interface_yaml'
	fuel node --node-id $node_id --net -u
	'
}

function check_dom0_iptables {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host 'iptables-save'
}

function verify_network {
	# Do network verification and wait for result
	# return 1 when passes, return 0 when failed or retrial timeout
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux

	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel network --verify --env $env_id &> /dev/null
	'

	local ok
	for i in {0..60}; do
		task=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel task | grep verify_networks
		')
		status=$(echo $task | awk -F '|' '{print $2}' | tr -d " ")
		progress=$(echo $task | awk -F '|' '{print $5}' | tr -d " ")
		if [ "$status" == "error" ]; then
			echo 1
			return
		fi
		if [ "${progress:-0}" -eq "100" ]; then
			echo 0
			return
		fi
		sleep 10
	done
	echo 1
}

function verify_network_and_retry {
	local fm_ip="$1"
	local env_name="$2"
	local xs_host="$3"
	for i in {0..10}; do
		network_verified=$(verify_network "$fm_ip" "$env_name")
		if [ "$network_verified" -eq 0 ]; then
			echo 0
			return
		fi

		# In case both nodes are disconnected
		ssh -qo StrictHostKeyChecking=no root@$xs_host '/etc/udev/scripts/recreate-gateway.sh'
	done
	echo 1
}

function deploy_env {
	local fm_ip="$1"
	local env_name="$2"
	set +x
	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux

	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel deploy-changes --env $env_id &> /dev/null
	'
	set -x
}

function print_env_messages {
	local fm_ip="$1"

	ssh -qo StrictHostKeyChecking=no root@$fm_ip 'fuel notifications'
}

function check_env_status {
	local fm_ip="$1"
	local env_name="$2"

	success=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
	'
	set -eux

	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel env --env $env_id | grep -q operational
	echo $?
	')
	[ "$success" = "0" ] && echo 0
}

FM_IP=$(get_fm_ip "$XS_HOST" "Fuel$FUEL_VERSION")

if [ -z "$FUEL_PLUGIN_FILE" ]; then
    # if not specify FUEL_PLUGIN_FILE, let's build it.
    build_plugin $FM_IP $FUEL_VERSION $FUEL_PLUGIN_REFSPEC
    echo "Fuel plugin with $FUEL_PLUGIN_REFSPEC is built"
else
    # copy file to FM
    ssh -qo StrictHostKeyChecking=no root@$FM_IP \
        '
set -ex
mkdir -p /root/fuel-plugin-xenserver/output/
'
    scp -qo StrictHostKeyChecking=no $FUEL_PLUGIN_FILE root@$FM_IP:/root/fuel-plugin-xenserver/output/
    
fi

install_plugin "$FM_IP"
echo "Fuel plugin is installed"

create_env "$FM_IP" "$ENV_NAME" "${REL_NAME[$FUEL_VERSION]}" "$ATTRIBUTES_YAML$FUEL_VERSION" "$NETWORK_YAML$FUEL_VERSION"

COMPUTE_MAC=$(get_node_mac "$XS_HOST" "Compute")
[ -z "$COMPUTE_MAC" ] && echo "Compute node doesnot exist" && exit -1
COMPUTE_DISCOVERED=$(wait_for_node_reboot_and_retry "$FM_IP" "$COMPUTE_MAC" "$XS_HOST" "Compute")
[ -z "$COMPUTE_DISCOVERED" ] && echo "Compute node discovery timeout" && exit -1
add_env_node "$FM_IP" "$ENV_NAME" "$COMPUTE_MAC" "compute,cinder" "$INTERFACE_YAML$FUEL_VERSION"

echo "Compute Node added"

CONTROLLER_MAC=$(get_node_mac "$XS_HOST" "Controller")
[ -z "$CONTROLLER_MAC" ] && echo "Controller node doesnot exist" && exit -1
CONTROLLER_DISCOVERED=$(wait_for_node_reboot_and_retry "$FM_IP" "$CONTROLLER_MAC" "$XS_HOST" "Controller")
[ -z "$CONTROLLER_DISCOVERED" ] && echo "Controller node discovery timeout" && exit -1

if [ -n "$IS_CEILOMETER_SUPPORTED" ]; then
    add_env_node "$FM_IP" "$ENV_NAME" "$CONTROLLER_MAC" "controller,mongo" "$INTERFACE_YAML$FUEL_VERSION"
else
    add_env_node "$FM_IP" "$ENV_NAME" "$CONTROLLER_MAC" "controller" "$INTERFACE_YAML$FUEL_VERSION"
fi
echo "Controller Node added"

check_dom0_iptables "$XS_HOST"
NETWORK_VERIFIED=$(verify_network_and_retry "$FM_IP" "$ENV_NAME" "$XS_HOST")
[ "$NETWORK_VERIFIED" -ne 0 ] && echo "Network verification failed" && exit -1

deploy_env "$FM_IP" "$ENV_NAME"

print_env_messages "$FM_IP"

SUCCESS=$(check_env_status "$FM_IP" "$ENV_NAME")
[ "$SUCCESS" != "0" ] && echo "Deployment failed" && exit -1

exit 0
