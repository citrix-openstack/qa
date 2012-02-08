#!/usr/bin/env bash
set -o errexit
set -o xtrace

# get tempest from git hub
cd /tmp
rm -rf /tmp/tempest
git clone https://github.com/openstack/tempest.git
cd /tmp/tempest

#
# configure tempest
#

# TODO - what about the dev stack script?
cp etc/tempest.conf.sample etc/tempest.conf

# Update to our default API_KEY and tenant
API_KEY=citrix # TODO - get from config file
sed -i "s/^api_key=.*$/api_key=$API_KEY/g" etc/tempest.conf
sed -i "s/^tenant_name=.*$/tenant_name=admin/g" etc/tempest.conf

# get hold of the image ref
# TODO - share this code
pushd /opt/stack/devstack
source ./openrc
popd
TOKEN=`curl -s -d  "{\"auth\":{\"passwordCredentials\": {\"username\": \"$NOVA_USERNAME\", \"password\": \"$NOVA_PASSWORD\"}}}" -H "Content-type: application/json" http://$HOST_IP:5000/v2.0/tokens | python -c "import sys; import json; tok = json.loads(sys.stdin.read()); print tok['access']['token']['id'];"`
IMAGE_REF=`glance -A $TOKEN index | egrep ami | cut -d" " -f1`

sed -i "s/^image_ref=.*$/image_ref=$IMAGE_REF/g" etc/tempest.conf

# run tempest
nosetests -v tempest