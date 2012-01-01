#!/bin/bash

set -eux

for node in $@
do
  echo "Checking if node $node is logging to remote VPX".
  result=$(cat /tmp/syslog | awk '{ print $4 }' | grep --ignore-case $node | wc -l)
  if [ $result -eq 0 ]
  then
    echo "No logging traces found for node: $node."
    exit 1
  else
    echo "Found $result logging traces for node: $node."
  fi
done