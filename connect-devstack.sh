#!/bin/bash
#
# This script connects an existing devstack (host 2) installation to devstack (host 1)

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

set -u

if [ ! -e $PrivID ]; then
    echo "ID file $PrivID does not exist; Please specify valid private key"
    exit 1
fi

ssh_options="-o BatchMode=yes -o StrictHostKeyChecking=no "
ssh_options+="-o UserKnownHostsFile=/dev/null -i $PrivID"

function hostToDevstack() {
    local __resultvar=$2
    # Check if it's a XS host and we know how to get to the devstack DomU...
    echo "$1 does not appear to be a devstack environment.  Assume XAPI-compatible and trying to auto detect devstack VM"
    ips=`ssh -o LogLevel=quiet $ssh_options root@$1 "xe vm-list name-label=DevStackOSDomU params=networks"`
    if [ -z "$ips" ]; then
	echo "No IPs - cannot detect domU"
    fi
    new_Devstack=`echo "$ips" | sed -e 's#.*2/ip: \([0-9.]*\).*#\1#'`
    ssh -o LogLevel=quiet $ssh_options stack@$new_Devstack /bin/true >/dev/null 2>&1
    if [ $? != 0 ] ; then
	echo "Failed to identify devstack VM from $1"
	exit 1
    fi
    echo "Found DevStack VM as $new_Devstack"
    eval $__resultvar="'$new_Devstack'"
}

# Test if we have the right host
ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    hostToDevstack $Devstack1 new_Devstack1
    Devstack1=$new_Devstack1
fi
ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    hostToDevstack $Devstack2 new_Devstack2
    Devstack2=$new_Devstack2
fi

set -ex

# Temporary directory
tmpdir=`mktemp -d`
#trap "rm -rf $tmpdir" EXIT

# Get the localrcs
scp $ssh_options stack@$Devstack1:devstack/localrc $tmpdir/devstack1_localrc
scp $ssh_options stack@$Devstack2:devstack/localrc $tmpdir/devstack2_localrc

# Make sure that we're not already a slave
if [ `grep -c "GLANCE_HOSTPORT" $tmpdir/devstack2_localrc` -gt 0 ]; then
    masterIP=`grep "GLANCE_HOSTPORT" $tmpdir/devstack2_localrc`
    masterIP=${masterIP#GLANCE_HOSTPORT=}
    masterIP=${masterIP%%:*}
    echo "It seems as though $Devstack2 is already connected to a master: $masterIP"
    exit 1
fi

# If Devstack1 already knows about the name of our Devstack2 host, we need to change Devstack2's hostname
master_hosts_known=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 "nova-manage service list | grep nova-compute"`
slaveHost=`ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "hostname"`

existingComputeCount=`echo $master_hosts_known | grep -c "nova-compute"`
if [ $existingComputeCount -gt 1 ]; then
    echo "This script only works for the first compute node being added"
    exit 1
fi

# Grep returns an error code if it doesn't find any!
set +e
numMatch=`echo "$master_hosts_known" | grep nova-compute | grep -c $slaveHost`
set -e
if [ $numMatch -gt 0 ]; then
    # Duplicate entries in /etc/hosts to make sudo happy
#    ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "sudo sed -i -e '/$slaveHost/p;s/$slaveHost/$slaveHost$numMatch/' /etc/hosts"
    # Change hostname on slave to add the count
    ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "sudo hostname $slaveHost$numMatch"
    ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "sudo sed -i 's/$slaveHost/$slaveHost$numMatch/' /etc/hosts"
    slaveHost=$slaveHost$numMatch
fi

# Get the IP address
master_iface=`grep HOST_IP_IFACE $tmpdir/devstack1_localrc`
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
GUEST_NAME=$slaveHost
EOF

scp $ssh_options $tmpdir/devstack2_localrc stack@$Devstack2:devstack/localrc 
ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "devstack/unstack.sh"
ssh -o LogLevel=quiet $ssh_options stack@$Devstack2 "devstack/stack.sh"
