#!/bin/bash
set -eux

BUILD_VERSION="$1"
REPO_URL="$2"
COMMIT="$3"

git clone $REPO_URL xenserver-core
cd xenserver-core
git fetch origin '+refs/pull/*:refs/remotes/origin/pr/*'

git checkout $COMMIT
git log -1 --pretty=format:%H

if [ -z "${PKG_REPO_LOCATION:-}" ]; then
    rsync -a xscore_rpm_producer@unsteve.eng.hq.xensource.com:/xscore/$BUILD_VERSION/ ./
fi

bash scripts/rpm/install.sh
