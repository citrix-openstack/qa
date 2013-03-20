set -exu

cd devstack
./unstack.sh || true
sudo vgremove stack-volumes || true
sudo pvcreate /dev/xvdb
sudo vgcreate stack-volumes /dev/xvdb
./stack.sh 2>&1 >>stacklog </dev/null
