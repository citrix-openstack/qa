#!/bin/sh

set -eux

DEST="/tmp/outgoing-bugtool"

thisdir=$(dirname "$0")

. "$thisdir/common.sh"

url="$1"
vpx_password="$2"

cd "$thisdir"

wget -q "$url/os-vpx-bugtool-all.noarch.rpm"

rpm -e os-vpx-bugtool-all || true
rpm -U os-vpx-bugtool-all.noarch.rpm

out=$(os-vpx-bugtool-all "$vpx_password")
fname=$(echo "$out" | \
        sed -ne 's,^Completed bugtool collection: \(.*\)\.$,\1,p')

if [ "$fname" ]
then
  rm -f "$DEST"
  ln -s "$fname" "$DEST"
  echo "Bugtool retrieval successful.  Linked $DEST to $fname."
else
  echo "Bugtool retrieval failed.  Output follows:"
  echo "$out"
  echo "Output ends."
  exit 1
fi
