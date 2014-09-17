#!/bin/bash
set -eux

HOST="$1"
XENSERVER_PASSWORD="$2"
REFERENCE="$3"
UBUNTU_DISTRO="$4"
USE_EXTERNAL_UBUNTU_REPO="$5"
UBUNTU_INST_HTTP_HOSTNAME="$6"
UBUNTU_INST_HTTP_DIRECTORY="$7"

WORKER=$(cat jenkins/jobs/xslib/get-worker.sh | jenkins/jobs/remote/bash.sh $HOST)

jenkins/jobs/remote/bash.sh $WORKER << EOF
set -eux

sudo apt-get update

sudo apt-get -qy install sshpass git

git clone http://github.com/citrix-openstack/qa.git

cd qa

ssh-keygen -t rsa -N "" -f devstack_key.priv
ssh-keyscan $HOST >> ~/.ssh/known_hosts

EXTRA_OPT=""
PREFIX="internal"
if [ "$USE_EXTERNAL_UBUNTU_REPO" = "yes" ]; then
    EXTRA_OPT="-x"
    PREFIX="external"
fi

FNAME="\$PREFIX-$UBUNTU_DISTRO.xva"

./generate-citrix-job.sh "$REFERENCE" \
  -u "$UBUNTU_DISTRO" \
  -m "$UBUNTU_INST_HTTP_HOSTNAME" \
  -n "$UBUNTU_INST_HTTP_DIRECTORY" \
  \$EXTRA_OPT > installer.sh

# Ignore devstack failures, as we are only using it to create JeOS
bash installer.sh $HOST $XENSERVER_PASSWORD devstack_key.priv || true

bash installer.sh $HOST $XENSERVER_PASSWORD devstack_key.priv -e \$FNAME

sshpass -p ubuntu \
  scp \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    \$FNAME ubuntu@copper.eng.hq.xensource.com:/usr/share/nginx/www/jeos

sshpass -p ubuntu \
  ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@copper.eng.hq.xensource.com chmod o+r /usr/share/nginx/www/jeos/\$FNAME
EOF
