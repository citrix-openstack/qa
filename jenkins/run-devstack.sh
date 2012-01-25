#!/bin/bash

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common.sh"

enter_jenkins_test

sudo su -c "$thisdir/devstack/jenkins_build_vpx.sh" root
