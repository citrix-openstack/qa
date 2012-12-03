#!/bin/bash

set -u

JENKINS_MASTER="$1"

cat backup-config.sh | ssh $JENKINS_MASTER 
scp $JENKINS_MASTER:/tmp/configs.tar .
