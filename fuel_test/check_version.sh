#!/bin/bash

#set -eux

. localrc

[ $DEBUG == "on" ] && set -x

if [[ ! -d "/tmp/fuel-plugin-xenserver" ]]; then
	git clone https://review.openstack.org/openstack/fuel-plugin-xenserver /tmp/fuel-plugin-xenserver
fi
cd /tmp/fuel-plugin-xenserver
git fetch https://review.openstack.org/openstack/fuel-plugin-xenserver "$FUEL_PLUGIN_REFSPEC"
git checkout FETCH_HEAD

exit 0