#!/bin/bash

set -e
set -x
set -u

NFS_SERVER="${1-copper.eng.hq.xensource.com}"
NFS_SERVERPATH="${2-/func-volume-test}"

function amend_localrc_for_xenapinfs
{
(
cd $HOME/devstack

eval `grep XENAPI_PASSWORD localrc`
eval `grep XENAPI_CONNECTION_URL localrc`

cat >> localrc << EOF
# CONFIGURE XenAPINFS
CINDER_DRIVER=XenAPINFS
CINDER_XENAPI_CONNECTION_URL=$XENAPI_CONNECTION_URL
CINDER_XENAPI_CONNECTION_USERNAME=root
CINDER_XENAPI_CONNECTION_PASSWORD=$XENAPI_PASSWORD
CINDER_XENAPI_NFS_SERVER=$NFS_SERVER
CINDER_XENAPI_NFS_SERVERPATH=$NFS_SERVERPATH
EOF
)
}

function restart_devstack
{
(
cd $HOME
./run.sh
)
}

amend_localrc_for_xenapinfs
restart_devstack
