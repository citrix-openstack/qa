#!/bin/bash

set -eu

timeout 5m ./clear_env.sh
[ $? -ne 0 ] && echo clear_env execution timeout && exit -1
timeout 5m ./check_version.sh
[ $? -ne 0 ] && echo check_version execution timeout && exit -1

if [[ -d "/tmp/fuel-plugin-xenserver" ]]; then
	export FUEL_VERSION=$(grep "fuel_version:" /tmp/fuel-plugin-xenserver/plugin_source/metadata.yaml | egrep -o "[0-9]+\." | egrep -o "[0-9]+")
fi

timeout 30m ./prep_env.sh
[ $? -ne 0 ] && echo prep_env execution timeout && exit -1
timeout 120m ./deploy_env.sh
[ $? -ne 0 ] && echo deploy_env execution timeout && exit -1
timeout 60m ./test_env.sh
[ $? -ne 0 ] && echo test_env execution timeout && exit -1
