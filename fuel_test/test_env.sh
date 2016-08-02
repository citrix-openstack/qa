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

function health_check {
	# Run a health check excluding HA tests and default credential tests
	local fm_ip="$1"
	local env_name="$2"

	result=$(ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel --env $env_id health --check tests_platform
	fuel --env $env_id health --check cloudvalidation
	fuel --env $env_id health --check sanity
	fuel --env $env_id health --check smoke
	')
	echo $result
}

function archive_log {
	# Run a health check excluding HA tests and default credential tests
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	set -eux
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	mkdir -p /tmp/fuel-plugin-xenserver

	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")

	compute_ip=$(fuel node --env "$env_id" | grep compute | egrep -o "10\\.20\\.0\\.([0-9])+")
	scp $compute_ip:/var/log/fuel-plugin-xenserver/compute_post_deployment.log /tmp/fuel-plugin-xenserver
	scp $compute_ip:/var/log/nova-all.log /tmp/fuel-plugin-xenserver

	controller_ip=$(fuel node --env "$env_id" | grep controller | egrep -o "10\\.20\\.0\\.([0-9])+")
	scp $controller_ip:/var/log/fuel-plugin-xenserver/controller_post_deployment.log /tmp/fuel-plugin-xenserver
	scp $controller_ip:/var/log/neutron-all.log /tmp/fuel-plugin-xenserver

	if [ "'$FM_VERSION'" == "8.0" ]; then
		docker cp fuel-core-8.0-astute:/var/log/astute/astute.log /tmp/fuel-plugin-xenserver
		docker cp fuel-core-8.0-ostf:/var/log/ostf.log /tmp/fuel-plugin-xenserver
		docker cp fuel-core-8.0-mcollective:/var/log/mcollective.log /tmp/fuel-plugin-xenserver
	else
		cp /var/log/astute/astute.log /tmp/fuel-plugin-xenserver
		cp /var/log/ostf.log /tmp/fuel-plugin-xenserver
		cp /var/log/mcollective.log /tmp/fuel-plugin-xenserver
	fi
	'

	scp -rqo stricthostkeychecking=no root@$fm_ip:/tmp/fuel-plugin-xenserver/ "$FUEL_TEST_LOG_DIR"
}

FM_IP=$(get_fm_ip "$XS_HOST" "$FM_NAME")
result=$(health_check "$FM_IP" "$ENV_NAME")
RESULT=$(comm -3 \
<(echo -e $result | egrep -o "\[failure\] '[^\']+'" | sed -e "s|\[failure\] ||g" | sed -e "s|'||g" | sort) \
<(printf '%s\n' "${IGNORE_CHECKS[@]}" | sort))
archive_log "$FM_IP" "$ENV_NAME"
[[ -n "$RESULT" ]] && echo "$RESULT" && exit 1
touch "$FUEL_TEST_SUCCESS"