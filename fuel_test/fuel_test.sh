#!/bin/bash

set -eu

timeout 5m ./clear_env.sh
[ $? -ne 0 ] && echo clear_env execution timeout && exit -1
timeout 5m ./check_version.sh
[ $? -ne 0 ] && echo check_version execution timeout && exit -1

if [[ -d "/tmp/fuel-plugin-xenserver" ]]; then
    # determine FUEL_VERSION
	if [ -f "/tmp/fuel-plugin-xenserver/plugin_source/metadata.yaml" ]; then
		export FUEL_VERSION=$(grep "fuel_version:" /tmp/fuel-plugin-xenserver/plugin_source/metadata.yaml | egrep -o "[0-9]+\." | egrep -o "[0-9]+")
	else
		export FUEL_VERSION=$(grep "fuel_version:" /tmp/fuel-plugin-xenserver/metadata.yaml | egrep -o "[0-9]+\." | egrep -o "[0-9]+")
	fi

    # determine if ceilomter is supported in this version of plugin.
    export IS_CEILOMETER_SUPPORTED=""
    if [ -z "$FORCE_DISABLE_CEILOMETER" -a -f "/tmp/fuel-plugin-xenserver/plugin_source/components.yaml" ]; then
        if ! grep "additional_service:ceilometer" /tmp/fuel-plugin-xenserver/plugin_source/components.yaml >/dev/null; then
            echo "INFO: Will enable ceilomter."
            export IS_CEILOMETER_SUPPORTED="YES"
            cp env_attributes.yaml9.ceilometer env_attributes.yaml9
        fi
    fi
fi

trap ./archive_log.sh EXIT

timeout 30m ./prep_env.sh
[ $? -ne 0 ] && echo prep_env execution timeout && exit -1
timeout 120m ./deploy_env.sh
[ $? -ne 0 ] && echo deploy_env execution timeout && exit -1
timeout 60m ./test_env.sh
[ $? -ne 0 ] && echo test_env execution timeout && exit -1
