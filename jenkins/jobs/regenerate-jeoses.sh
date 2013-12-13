#!/bin/bash
set -eux

HOST="$1"
XENSERVER_PASSWORD="$2"

WORKER=$(cat jenkins/jobs/xslib/get-worker.sh | jenkins/jobs/remote/bash.sh $HOST)

jenkins/jobs/remote/bash.sh $WORKER << EOF
set -eux

sudo apt-get update

sudo apt-get -qy install sshpass

wget -qO install-devstack-xen.sh https://raw.github.com/citrix-openstack/qa/master/install-devstack-xen.sh

ssh-keygen -t rsa -N "" -f devstack_key.priv

ssh-keyscan $HOST >> ~/.ssh/known_hosts

bash install-devstack-xen.sh $HOST $XENSERVER_PASSWORD devstack_key.priv

bash install-devstack-xen.sh $HOST $XENSERVER_PASSWORD devstack_key.priv -e external-precise.xva

sshpass -p ubuntu \
  scp \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    external-precise.xva ubuntu@copper.eng.hq.xensource.com:/usr/share/nginx/www/jeos

shpass -p ubuntu \
  ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@copper.eng.hq.xensource.com chmod o+r /usr/share/nginx/www/jeos/external-precise.xva
EOF
