#!/bin/bash

set -eux

# If XCP is 1.9.0 (XS6.54) and branch is master, no need test
. localrc
xcp_ver=$(ssh -qo StrictHostKeyChecking=no root@$XS_HOST \
          'xe host-param-get uuid=$(xe host-list --minimal) \
          param-name=software-version param-key=platform_version')
if [ "$xcp_ver" = "1.9.0" ] && [ "$REPO_BRANCH" = "master" ]; then
    echo "XS6.5 is deprecated on master branch (MOS10)"
    touch "$FUEL_TEST_SUCCESS"
    exit 0
fi

timeout 5m ./clear_env.sh
[ $? -ne 0 ] && echo clear_env execution timeout && exit -1

# basing on hypervisor version to customize env_attributes yaml files
hypervisor=${hypervisor:-xenserver}
sed -i "s/{hypervisor}/$hypervisor/g" env_attributes.yaml*

# only check version when FUEL_VERSION is not set; so that allow to
# specify FUEL_VERSION before hand.
if [ "${FUEL_VERSION:-None}" != "None" ]; then
    if [ $FUEL_VERSION -ge 9 ]; then
        # Force to enable ceilometer for Fuel9.0 or above,
        # if not forcing to disable ceilometer.
        if [ -z "$FORCE_DISABLE_CEILOMETER" ]; then
            echo "INFO: Will enable ceilomter."
            export IS_CEILOMETER_SUPPORTED="YES"
            cp env_attributes.yaml9.ceilometer env_attributes.yaml9
        fi
    fi
else
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
fi

trap ./archive_log.sh EXIT

timeout 30m ./prep_env.sh
[ $? -ne 0 ] && echo prep_env execution timeout && exit -1
timeout 120m ./deploy_env.sh
[ $? -ne 0 ] && echo deploy_env execution timeout && exit -1
timeout 60m ./test_env.sh
[ $? -ne 0 ] && echo test_env execution timeout && exit -1
