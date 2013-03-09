cd devstack
. openrc admin

set -exu

function extract_id {
    sed -e 's/^| //g' -e 's/ |.*$//g'
}

function sleepwhile {
    while $@
    do
        sleep 1
    done
}

function sleepwhilenot {
    while ! $@
    do
        sleep 1
    done
}

function upload_image {
    glance image-list | grep $1 || {
        glance image-create --name $1 \
        --copy-from=https://github.com/downloads/citrix-openstack/warehouse/cirros-0.3.0-x86_64-disk.vhd.tgz \
        --container-format=ovf --disk-format=vhd --is-public=True --property auto_disk_config=true \
        --min-disk=1 --min-ram=256
    }
}

function image_is_active {
    glance image-list | grep $1 | grep active
}

function addflavor {
    nova-manage flavor create --name=$2 --memory=512 --cpu=1 --root_gb=$3 \
    --flavor=$1 --swap=0 --rxtx_factor=1.0 --is_public=true || true
}

function imageid {
    glance image-list | grep $1 | extract_id
}

upload_image tempestimage
sleepwhilenot image_is_active tempestimage
addflavor 7 m1.onegig 1
addflavor 8 m1.twogig 2

IMAGEID=$(imageid tempestimage)

[ ! -z "$IMAGEID" ]

TEMPESTCONFIG=/opt/stack/tempest/etc/tempest.conf

# tempest.tests.compute.images.test_images_oneserver:ImagesOneServerTestJSON.test_create_delete_image
# might break, if the flavor's disk is bigger than the image
sed -i \
-e "s,\(^image_ref =\).*$,\1 $IMAGEID,g" \
-e "s,\(^image_ref_alt =\).*$,\1 $IMAGEID,g" \
-e "s,\(^flavor_ref_alt =\).*$,\1 8,g" \
-e "s,\(^flavor_ref =\).*$,\1 7,g" \
$TEMPESTCONFIG
