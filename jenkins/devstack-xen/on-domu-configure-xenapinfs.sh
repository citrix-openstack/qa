#!/bin/bash

set -e
set -x
set -u

function amend_localrc_for_xenapinfs
{

eval `grep XENAPI_PASSWORD localrc`
eval `grep XENAPI_CONNECTION_URL localrc`

cd $HOME/devstack
cat >> localrc << EOF
# CONFIGURE XenAPINFS
CINDER_DRIVER=XenAPINFS
CINDER_XENAPI_CONNECTION_URL=$XENAPI_CONNECTION_URL
CINDER_XENAPI_CONNECTION_USERNAME=root
CINDER_XENAPI_CONNECTION_PASSWORD=$XENAPI_PASSWORD
CINDER_XENAPI_NFS_SERVER=copper.eng.hq.xensource.com
CINDER_XENAPI_NFS_SERVERPATH=/func-volume-test
EOF
}

function restart_devstack
{
cd $HOME
./run.sh
}

amend_localrc_for_xenapinfs
restart_devstack
