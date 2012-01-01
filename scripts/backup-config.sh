#!/bin/sh

set -eu

cd ~
find -name users -prune -o \
     -name config-history -prune -o \
     -name workspace -prune -o \
     -name config.xml -print | xargs tar cvf configs.tar
