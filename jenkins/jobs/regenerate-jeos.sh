#!/bin/bash
set -eux

HOST="$1"
XENSERVER_PASSWORD="$2"
REFERENCE="$3"
UBUNTU_DISTRO="$4"
USE_EXTERNAL_UBUNTU_REPO="$5"
UBUNTU_INST_HTTP_HOSTNAME="$6"
UBUNTU_INST_HTTP_DIRECTORY="$7"

TMP=$(mktemp -d)

ssh-keygen -t rsa -N "" -f $TMP/devstack_key.priv
ssh-keyscan $HOST >> ~/.ssh/known_hosts

EXTRA_OPT=""
PREFIX="internal"
if [ "$USE_EXTERNAL_UBUNTU_REPO" = "yes" ]; then
    EXTRA_OPT="-x"
    PREFIX="external"
fi

FNAME="/usr/share/nginx/www/jeos/$PREFIX-$UBUNTU_DISTRO.xva"

./generate-citrix-job.sh "$REFERENCE" \
  -u "$UBUNTU_DISTRO" \
  -m "$UBUNTU_INST_HTTP_HOSTNAME" \
  -n "$UBUNTU_INST_HTTP_DIRECTORY" \
  $EXTRA_OPT > $TMP/installer.sh

# Ignore devstack failures, as we are only using it to create JeOS
bash $TMP/installer.sh $HOST $XENSERVER_PASSWORD $TMP/devstack_key.priv -n || true

# Requires passwordless SSH to copper
bash $TMP/installer.sh $HOST $XENSERVER_PASSWORD $TMP/devstack_key.priv -e ubuntu@copper.eng.hq.xensource.com:$FNAME


ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@copper.eng.hq.xensource.com chmod o+r $FNAME
