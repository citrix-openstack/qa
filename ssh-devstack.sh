#!/bin/bash

function syntax {
    echo "SSHs in to the devstack on the XS host"
    echo
    echo "Syntax: $0 <private key> <host>"
    exit 1
}

PrivID=${1:-$PrivID}
Devstack1=${2:-$Devstack1}

[ -z $Devstack1 ] && syntax

set -u

if [ ! -e $PrivID ]; then
    echo "ID file $PrivID does not exist; Please specify valid private key"
    exit 1
fi

ssh_options="-o BatchMode=yes -o StrictHostKeyChecking=no "
ssh_options+="-o UserKnownHostsFile=/dev/null -i $PrivID -X"

function hostToDevstack() {
    local __resultvar=$2
    # Check if it's a XS host and we know how to get to the devstack DomU...
    echo "$1 does not appear to be a devstack environment.  Assume XAPI-compatible and trying to auto detect devstack VM"
    ips=`ssh -o LogLevel=quiet $ssh_options root@$1 "xe vm-list other-config:os-vpx=true params=networks"`
    if [ -z "$ips" ]; then
	echo "No IPs - cannot detect domU"
        exit 1
    fi
    ips=`echo $ips | sed -e 's#/ip: #\n#g' | sed -e 's/;.\+//' -e '1d'`
    for new_ip in $ips; do
        if [ $new_ip == '10.255.255.255' ]; then
            echo "Skipping $new_ip"
            continue
        fi
        echo "Attempting to log in to devstack VM $new_ip"
        ssh -o LogLevel=quiet $ssh_options stack@$new_ip /bin/true >/dev/null 2>&1
        if [ $? == 0 ] ; then
            echo "Found DevStack VM as $new_ip"
            eval $__resultvar="'$new_ip'"
            return
        fi
    done
    echo "Could not find devstack"
    exit 1
}

# Test if we have the right host
ssh -o LogLevel=quiet $ssh_options stack@$Devstack1 /bin/true >/dev/null 2>&1
if [ $? != 0 ] ; then
    hostToDevstack $Devstack1 new_Devstack1
    Devstack1=$new_Devstack1
fi

ssh -o LogLevel=quiet $ssh_options stack@$Devstack1
