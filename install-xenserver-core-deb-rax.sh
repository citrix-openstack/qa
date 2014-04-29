#!/bin/bash
set -eux

TARGET_PLATFORM=`cat /etc/debian_version`
BUILD_VERSION=${TARGET_PLATFORM%%/*}_`date +%y%m%d`

apt-get -qy update
apt-get -qy upgrade

apt-get -qy install git

git clone https://github.com/BobBall/xenserver-core.git -b master xenserver-core

cd xenserver-core

rsync -a xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$BUILD_VERSION/deb/ RPMS
rsync -a xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$BUILD_VERSION/deb-src/ SRPMS

bash scripts/deb/install.sh

ssh-agent -k