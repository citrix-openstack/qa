#!/bin/bash

#set -eux

. localrc

[ $DEBUG == "on" ] && set -x

if [[ ! -d "/tmp/fuel-plugin-xenserver" ]]; then
	git clone ${REPO_URL}/openstack/fuel-plugin-xenserver -b ${REPO_BRANCH} /tmp/fuel-plugin-xenserver
fi
cd /tmp/fuel-plugin-xenserver
git fetch ${FETCH_URL}/openstack/fuel-plugin-xenserver "${FUEL_PLUGIN_REFSPEC}"
git checkout FETCH_HEAD

exit 0
