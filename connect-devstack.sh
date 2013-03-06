#!/bin/bash
#
# This script connects an existing devstack (host 2) installation to devstack (host 1)

set -e

function syntax {
    echo "Connects devstack2 to devstack1"
    echo
    echo "Syntax: $0 <private key> <devstack1> <devstack2>"
    echo "Environment variables \$PrivID, \$Devstack1 and"\
	" \$Devstack2 can be used as an alternative"
    exit 1
}

PrivID=${1:-$PrivID}
Devstack1=${2:-$Devstack1}
Devstack2=${3:-$Devstack2}

[ -z $Devstack1 ] && syntax
[ -z $Devstack2 ] && syntax

if [ ! -e $PrivID ]; then
    echo "ID file $PrivID does not exist; Please specify valid private key"
    exit 1
fi

ssh_options="-o BatchMode=yes -o StrictHostKeyChecking=no "
ssh_options+="-o UserKnownHostsFile=/dev/null -i $PrivID"

# Test if we have the right host
ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    echo "$Devstack1 does not appear to be a devstack environment"
fi
ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    echo "$Devstack2 does not appear to be a devstack environment"
fi

set -x

# Temporary directory
tmpdir=`mktemp -d`
#trap "rm -rf $tmpdir" EXIT

# Get the localrcs
scp $ssh_options stack@$Devstack1:devstack/localrc $tmpdir/devstack1_localrc
scp $ssh_options stack@$Devstack2:devstack/localrc $tmpdir/devstack2_localrc

# Make sure that we're not already a slave
if [ `grep -c "GLANCE_HOSTPORT" $tmpdir/devstack2_localrc` -gt 0 ]; then
    echo "It seems as though $Devstack2 is already connected to a master"
    exit 1
fi

# If Devstack1 already knows about the name of our Devstack2 host, we need to change Devstack2's hostname
master_hosts_known=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 "nova-manage service list | grep nova-compute"`
slave_hostname=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "hostname"`

existingComputeCount=`echo $master_hosts_known | grep -c "nova-compute"`
if [ $existingComputeCount -gt 1 ]; then
    echo "This script only works for the first compute node being added"
    exit 1
fi

# Grep returns an error code if it doesn't find any!
set +e
existingCount=`echo "$master_hosts_known" | grep nova-compute | grep -c $slave_hostname`
set -e
if [ $existingCount -gt 0 ]; then
    # Change hostname on slave to add the count
    ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "sudo hostname $slave_hostname$existingCount"
    ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "sudo sed -i 's/$slave_hostname/$slave_hostname$existingCount/' /etc/hosts"
    slave_hostname=$slave_hostname$existingCount
fi

# Get the IP address
master_iface=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 "grep HOST_IP_IFACE devstack/localrc"`
GuestIP=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 "ip -4 -o addr show ${master_iface/HOST_IP_IFACE=/} | sed -e 's/.*inet \([0-9.]*\).*/\1/'"`

cat >> $tmpdir/devstack2_localrc <<EOF
ENABLED_SERVICES="n-cpu,n-net,n-api,g-api,-mysql"
DATABASE_TYPE=mysql
MYSQL_HOST=$GuestIP
RABBIT_HOST=$GuestIP
KEYSTONE_AUTH_HOST=$GuestIP
GLANCE_HOSTPORT=$GuestIP:9292

# TODO - allow these to be configured
PUB_IP=172.24.4.11
VM_IP=10.255.255.254
GUEST_NAME=$slave_hostname
EOF

scp $ssh_options $tmpdir/devstack2_localrc stack@$Devstack2:devstack/localrc 
#ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "devstack/unstack.sh"
#ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "devstack/stack.sh"
