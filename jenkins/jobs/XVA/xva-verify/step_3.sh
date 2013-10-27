#!/bin/bash
set -eux

eval `cat "${BUILD_NUMBER}.properties"`

# Setup passwordless authentication
sshpass -p $XenServerPassword ssh-copy-id -i $HOME/.ssh/id_rsa root@$HOST

jenkins/jobs/xva-install.sh $HOST $DEVSTACK_XVA_URL $DEVSTACK_SUPPACK_URL

jenkins/jobs/xva-inject-password.sh $HOST $XenServerPassword

jenkins/jobs/xva-run-tests.sh $HOST
