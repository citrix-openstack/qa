#!/bin/bash
set -eux

rm -rf .env
virtualenv -p python2 .env

set +u
. .env/bin/activate
set -u

rm -rf dl
mkdir dl

pip install --download dl https://github.com/citrix-openstack/boxes/archive/master.zip
wget -qO - https://raw.githubusercontent.com/citrix-openstack/boxes/master/boxes/pdu-requirements.txt > reqs.txt
wget -qO - https://raw.githubusercontent.com/citrix-openstack/boxes/master/dev-requirements.txt >> reqs.txt
pip install --download dl -r reqs.txt
rm dl/master.zip


function scp_to_unsteve() {
    sshpass -p$InfraPass scp ${InfraUser}@unsteve.eng.hq.xensource.com "$@"
}

SSHPASS="sshpass -p$InfraPass"
SSHOPTS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l ${InfraUser}"

$SSHPASS ssh $SSHOPTS unsteve.eng.hq.xensource.com rm -f '/pip-dir/*'
$SSHPASS scp $SSHOPTS dl/* unsteve.eng.hq.xensource.com:/pip-dir/

