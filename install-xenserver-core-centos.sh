#!/bin/bash
set -eux

BUILD_VERSION="$1"

git clone https://github.com/xapi-project/xenserver-core.git -b master xenserver-core

cd xenserver-core

if [ -z "${PKG_REPO_LOCATION:-}" ]; then
    rsync -a xscore_rpm_producer@unsteve.eng.hq.xensource.com:/xscore/$BUILD_VERSION/ ./
fi

bash scripts/rpm/install.sh
