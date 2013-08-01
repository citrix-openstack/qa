#!/bin/bash

set -o xtrace
set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
BUILDLIB=$(cd $(dirname $(readlink -f "$0")) && cd builds && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 SERVERNAME

Build Nova Supplemental Pack

positional arguments:
 SERVERNAME     The name of the XenServer
EOF
exit 1
}

SERVERNAME="${1-$(print_usage_and_die)}"

echo "Spinning up virtual machine"
SLAVE_IP=$(cat $XSLIB/start-slave.sh |
    "$REMOTELIB/bash.sh" "root@$SERVERNAME")

echo "Starting job on $SLAVE_IP"
"$REMOTELIB/bash.sh" "ubuntu@$SLAVE_IP" <<_EOL_
cat > "build.sh" <<"_EOLI_"
`cat $BUILDLIB/devstack-xva/build.sh`
_EOLI_
cat > "build-inside-chroot.sh" <<"_EOLI_"
`cat $BUILDLIB/devstack-xva/build-inside-chroot.sh`
_EOLI_
cat > "mkxva.py" <<"_EOLI_"
`cat $BUILDLIB/devstack-xva/mkxva.py`
_EOLI_
cat > "ova.xml" <<"_EOLI_"
`cat $BUILDLIB/devstack-xva/ova.xml`
_EOLI_
chmod 755 build.sh
chmod 755 build-inside-chroot.sh
chmod 755 mkxva.py
sudo ./build.sh
kill `pidof "sshd: ubuntu@notty"`
_EOL_

echo "Copying build result to copper"
scp -B -3 -o 'StrictHostKeyChecking no' ubuntu@$SLAVE_IP:output.xva \
    jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/devstack.xva
echo "The build result is now located at: http://copper.eng.hq.xensource.com/builds/devstack.xva"

exit 0
