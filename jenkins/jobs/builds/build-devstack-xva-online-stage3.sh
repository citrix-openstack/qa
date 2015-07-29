#/bin/bash
set -eux

# Rename bridges (takes a long time)
wget --no-check-certificate -q "https://raw.github.com/citrix-openstack/qa/master/jenkins/jobs/xva-rename-bridges.py"
mkdir -p /mnt/exported-vms
apt-get -y install nfs-common || true
mount -t nfs copper.eng.hq.xensource.com:/exported-vms /mnt/exported-vms
python xva-rename-bridges.py /mnt/exported-vms/build-devstack-xva-online-stage2.xva /mnt/exported-vms/devstack.xva
rm /mnt/exported-vms/build-devstack-xva-online-stage2.xva

echo "Devstack XVA ready"

ls -lah /mnt/exported-vms/devstack.xva
umount /mnt/exported-vms


