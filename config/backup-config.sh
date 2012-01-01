#!/bin/sh

set -eu

cd ~
find -name users -prune -o \
     -name config-history -prune -o \
     -name forest.hg -prune -o \
     -name workspace -prune -o \
     -name config.xml -print | xargs tar cvf configs.tar

tmpdir=$(mktemp -d)
awk '{ if (found == 1) { print "          <string></string>"; found = 0; } else { print; } } /XS_ROOT_PASSWORD/ { found = 1; }; ' \
  <config.xml >"$tmpdir/config.xml"
tar -C "$tmpdir" -rf configs.tar ./config.xml
rm -rf "$tmpdir"
