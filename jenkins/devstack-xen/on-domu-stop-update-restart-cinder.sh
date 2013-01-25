#!/bin/bash

set -exu

pkill -HUP -f "/opt/stack/cinder/bin/cinder-volume"
sleep 1

cd cinder
git pull

NL=`echo -ne '\015'`
screen -S stack -p c-vol -X stuff "cd /opt/stack/cinder && /opt/stack/cinder/bin/cinder-volume --config-file /etc/cinder/cinder.conf$NL"
sleep 2
