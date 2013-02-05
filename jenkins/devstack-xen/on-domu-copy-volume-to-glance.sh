#!/bin/bash

cd devstack
. openrc admin

set -eux

function extract_id
{
sed -e 's/^| //g' -e 's/ |.*$//g'
}

function assert_status_is
{
glance image-list | grep imagefromvolume | grep "$1";
}

function wait_till_status_is_not
{
while glance image-list | grep imagefromvolume | grep "$1";
do
sleep 1
done
}

function given_volume_is_there
{
VOLID=`cinder list | grep created-volume | extract_id`
}

function when_upload_volume
{
# TODO cinder upload-to-image --container-format=ovf --disk-format=vhd $VOLID imagefromvolume
cinder upload-to-image $VOLID imagefromvolume
}

function then_volume_created
{
glance image-list | grep imagefromvolume
}

function given_imagefromvolume_deleted
{
glance image-list | grep imagefromvolume && (
glance image-list | grep imagefromvolume | while read i; do
glance image-delete `echo "$i" | extract_id`
done
while glance image-list | grep imagefromvolume;
do
sleep 1
done
) || true
}

given_imagefromvolume_deleted
given_volume_is_there
when_upload_volume
then_volume_created
wait_till_status_is_not "queued"
assert_status_is "active"

echo "TESTS PASSED"
