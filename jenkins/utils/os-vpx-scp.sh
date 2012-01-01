#!/bin/bash

set -eu

thisdir=$(dirname "$0")
. "$thisdir/common-vpx.sh"

password="$1"
ip_addr="$2"
src="$3"
dst="$4"

if [ -f ~/.ssh/id_rsa.pub ] && grep -q "OS-VPX devel key" ~/.ssh/id_rsa.pub
then
  devel_key=true
  keyfile=~/.ssh/id_rsa
else
  devel_key=false
  keyfile=$(mktemp)
  rm "$keyfile"
fi

if ! $devel_key
then
  gen_key
  upload_key "$ip_addr"
fi

echo -n "Remote copy of $src to $dst from $ip_addr."
scp_no_hosts "$ip_addr:$src" "$dst"
echo "done."