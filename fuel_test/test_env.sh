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
	fuel --env $env_id health --check smoke,sanity,tests_platform,cloudvalidation
	')
	echo $result
}

FM_IP=$(get_fm_ip "$XS_HOST" "$FM_NAME")
result=$(health_check "$FM_IP" "$ENV_NAME")
RESULT=$(comm -3 \
<(echo -e $result | egrep -o "\[failure\] '[^\']+'" | sed -e "s|\[failure\] ||g" | sed -e "s|'||g" | sort) \
<(printf '%s\n' "${IGNORE_CHECKS[@]}" | sort))
[[ -n $RESULT ]] && echo $RESULT && exit 1
exit 0