#!/bin/bash

set -x

function health_check {
	# Run a health check excluding HA tests and default credential tests
	local fm_ip="$1"
	local env_name="$2"

	ssh -qo stricthostkeychecking=no root@$fm_ip \
	'
	export fuelclient_custom_settings="/etc/fuel/client/config.yaml"
	env_id=$(fuel env | grep "'$env_name'" | egrep -o "^[0-9]+")
	fuel --env $env_id health --check smoke,sanity,tests_platform,cloudvalidation
	'
}

health_check "$FM_IP" "$ENV_NAME"
