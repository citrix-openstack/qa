#!/bin/bash

set -eu

thisdir=$(dirname "$0")
. "$thisdir/common-vpx.sh"

password="$1"
ip_addr="$2"
cmd="$3"

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

set +e
echo "Executing command on $ip_addr..."
out=$(ssh_no_hosts "$ip_addr" "$cmd")
code=$?
set -e
echo "Command output executed on $ip_addr: $out."
exit $code