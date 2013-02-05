#!/bin/bash

set -exu

pkill -HUP -f "/opt/stack/cinder/bin/cinder-volume" || true
sleep 1

cd cinder
git remote update
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git checkout origin/xenapinfs-glance-integration-v2i -B xenapinfs-glance-integration-v2i

NL=`echo -ne '\015'`
screen -S stack -p c-vol -X stuff "cd /opt/stack/cinder && /opt/stack/cinder/bin/cinder-volume --config-file /etc/cinder/cinder.conf$NL"
sleep 2
