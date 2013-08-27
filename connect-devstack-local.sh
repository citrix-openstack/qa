#!/bin/bash

# Connects the current devstack instance to the devstack instance specified by the IP given

set -exu

function replace_value() {
    key=$1
    value=$2

    grep -Ev "^$key=" ~/devstack/localrc > localrc.tmp
    mv localrc.tmp ~/devstack/localrc
    echo "$key=$value" >> ~/devstack/localrc
}

OtherDevstack=$1

# Get the localrc
scp stack@$OtherDevstack:devstack/localrc remote_localrc

# If Devstack1 already knows about the name of our Devstack2 host, we need to change Devstack2's hostname
master_hosts_known=`ssh -o LogLevel=quiet stack@$OtherDevstack "nova-manage service list 2>/dev/null | grep nova-compute"`

# Change our options
~/devstack/unstack.sh
cp ~/devstack/localrc ~/devstack/localrc.bck.`date +"%m_%d_%Y"`

slaveHost=`hostname`
existingComputeCount=`echo $master_hosts_known | grep -c "nova-compute"`

# Grep returns an error code if it doesn't find any!
set +e
numMatch=`echo "$master_hosts_known" | grep nova-compute | grep -c $slaveHost`
set -e

# Change hostname on slave to add the count
newHost=Compute$numMatch
cat > ~stack/change_hostname << EOF
#!/bin/bash
hostname $newHost
sed -i 's/$slaveHost/$newHost/g' /etc/hosts
echo $newHost > /etc/hostname
EOF
chmod a+x ~stack/change_hostname
sudo ~stack/change_hostname

replace_value GUEST_NAME $newHost
(
source remote_localrc
replace_value MYSQL_PASSWORD $MYSQL_PASSWORD
replace_value SERVICE_TOKEN $SERVICE_TOKEN
replace_value ADMIN_PASSWORD $ADMIN_PASSWORD
replace_value RABBIT_PASSWORD $RABBIT_PASSWORD
replace_value GUEST_PASSWORD $GUEST_PASSWORD
)
replace_value ENABLED_SERVICES "n-cpu,n-net,n-api"
replace_value DATABASE_TYPE "mysql" # TODO: Detect
replace_value SERVICE_HOST $OtherDevstack
replace_value MYSQL_HOST $OtherDevstack
replace_value RABBIT_HOST $OtherDevstack
replace_value KEYSTONE_AUTH_HOST $OtherDevstack
replace_value GLANCE_HOSTPORT $OtherDevstack:9292

~/devstack/stack.sh

echo Now you must re-source your openrc:
echo . ~/devstack/openrc admin
