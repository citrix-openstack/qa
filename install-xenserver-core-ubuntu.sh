#!/bin/bash
set -eux

BUILD_VERSION="$1"

apt-get -qy update
apt-get -qy upgrade

apt-get -qy install git

git clone https://github.com/xapi-project/xenserver-core.git -b master xenserver-core

cd xenserver-core

rsync -a xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$BUILD_VERSION/deb/ RPMS
rsync -a xscore_deb_producer@unsteve.eng.hq.xensource.com:/xenserver_core_debs/$BUILD_VERSION/deb-src/ SRPMS

# inject Keyfile for Launchpad PPA for Louis Gesbert
apt-key add - << KEYFILE
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: SKS 1.1.4
Comment: Hostname: keyserver.ubuntu.com

mI0EUgJE5QEEANHD2l6yuvqffhqTcJd4nOQVax6m9i4SKb/IpXqOh40PYzG17bc0rbGaM7CU
+nD9vDAtP6Wjjc5aatMyYOQ1aPzAmPtFfvjg9NyR88r9GK7G8sR6N2YzarUblrxI0yEmfc9X
409JOejfgv7s1D/Jmsoo5GqYQihXiSBS7juJk6ihABEBAAG0H0xhdW5jaHBhZCBQUEEgZm9y
IExvdWlzIEdlc2JlcnSIuAQTAQIAIgUCUgJE5QIbAwYLCQgHAwIGFQgCCQoLBBYCAwECHgEC
F4AACgkQrWm///0xBNZrugQAqEz0xu6FmNSvCtn9vVghI8/UAoYla87qHSjEY1gmQ9oC4/0Y
hPh2pBmI475HlPvESksjApsUHh9ksc9SkLiNS9rPE5rFp/gEDjFA6arFcaPcNmAu51x3lDfh
KQ3afU1hlF6EsITRd5qGry7ftxoLKOrVp8qSw9O/PdFgBTTGvgE=
=ZOqF
-----END PGP PUBLIC KEY BLOCK-----
KEYFILE

bash scripts/deb/install.sh
