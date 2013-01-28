#!/bin/bash

cd devstack
. openrc admin

set -eu

function extract_id
{
sed -e 's/^| //g' -e 's/ |.*$//g'
}

function given_image_is_there
{
glance image-list | grep cfgtest || (
glance image-create --name cfgtest \
--copy-from=https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz \
--container-format=ovf --disk-format=vhd
echo "Cirros image uploaded, waiting 10 secs for glance to settle"
sleep 10
)

IMAGEID=`glance image-list | grep cfgtest | extract_id`
}

function given_creating_volume_from_image
{
cinder create --display_name="created-volume" --image-id $IMAGEID 1
}

function given_no_created_volume
{
cinder list | grep created-volume && (
cinder list | grep created-volume | while read i; do
cinder delete `echo "$i" | extract_id`
done
while cinder list | grep created-volume;
do
sleep 1
done
) || true
}

function assert_status_is
{
cinder list | grep created-volume | grep "$1";
}

function wait_till_status_is_not
{
while cinder list | grep created-volume | grep "$1";
do
sleep 1
done
}

given_no_created_volume
given_image_is_there
given_creating_volume_from_image
wait_till_status_is_not "creating"
assert_status_is "downloading"
wait_till_status_is_not "downloading"
assert_status_is "available"

echo "TESTS PASSED"
