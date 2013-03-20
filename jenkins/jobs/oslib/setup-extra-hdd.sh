set -exu

cd devstack
./unstack.sh
sudo vgremove stack-volumes
sudo pvcreate /dev/xvdb
sudo vgcreate stack-volumes /dev/xvdb
./stack.sh 2>&1 >>stacklog </dev/null
