set -exu

rm -f /images
LOCAL_SR=$(xe sr-list name-label="Local storage" params=uuid --minimal)
[ ! -z "$LOCAL_SR" ]
IMG_DIR="/var/run/sr-mount/$LOCAL_SR/images"
mkdir -p "$IMG_DIR"
ln -s  "$IMG_DIR" /images
