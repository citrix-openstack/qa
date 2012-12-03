#!/bin/sh

set -eu

OUTPUT_FILE=${1:-"/tmp/configs.tar"}

cd /var/lib/jenkins
find -name users -prune -o \
     -name config-history -prune -o \
     -name workspace -prune -o \
     -name qa -prune -o \
     -name config.xml -print | xargs tar cvf $OUTPUT_FILE
