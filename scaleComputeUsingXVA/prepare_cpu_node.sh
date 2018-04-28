#!/bin/bash
set -ex

source ./readconfig.sh

ComputeHostName=$(readIni config.ini ComputeHost name)
ComputeHostIP=$(readIni config.ini ComputeHost ip)
ComputeHostUser=$(readIni config.ini ComputeHost user)
ComputeHostPassword=$(readIni config.ini ComputeHost password)
ComputeNodeName=$(readIni config.ini ComputeNode name)
ComputeNodeUser=$(readIni config.ini ComputeNode user)
ComputeNodePassword=$(readIni config.ini ComputeNode password)


#sshpass -p "xenroot" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@xrtmia-07-34.xenrt.citrite.net "pwd; ls"
# ssh_command $host $user $password $command
sudo apt-get install sshpass

function ssh_command {
    sshpass -p ${ComputeHostPassword} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${ComputeHostUser}@${ComputeHostIP} $@
}

VMUUID=""
VMIP=""
ControllerIP="10.62.66.6"


function import_cpu {
    importXva="xe vm-import filename=/root/computeNodeFinal.xva"
    VMUUID=$(ssh_command $importXva)
}

function start_cpu {
	start_cpu="xe vm-start uuid=$VMUUID"
	ssh_command $start_cpu
}

function get_xva_ip {
	local period=10
    local max_tries=10
    local i=0

    local get_ip="xe vm-param-get uuid=$VMUUID param-name=networks | tr ';' '\n' | grep '0/ip:' | cut -d: -f2"
    while true; do
    	if [ $i -ge $max_tries ]; then
    		echo "Timeout; ip address for VM: $VMUUID"
    		exit 11
    	fi

    	ipaddress=$(ssh_command $get_ip)
        
        if [ -z "$ipaddress" ]; then
        	sleep $period
        	i=$((i+1))
        else
        	VMIP=$(echo $ipaddress | sed s/[[:space:]]//g)
        	break
        fi
    done
}

function write_config {
	writeIni config.ini ComputeNode ip $VMIP
}

function ssh_cpu {
    sshpass -p ${ComputeNodePassword} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${ComputeNodeUser}@${VMIP} $@
}

function configure_cpu_hostIP {
        findfile="grep -lr computeHostIP /etc"
        files=$(ssh_cpu $findfile)
        for file in $files; do
            ssh_cpu sed -i \"s/computeHostIP/${ComputeHostIP}/g\" $file
        done
}

function configure_cpu_controllerIP {
        findfile="grep -lr controllerIP /etc"
        files=$(ssh_cpu $findfile)
        for file in $files; do
            ssh_cpu sed -i \"s/controllerIP/${ControllerIP}/g\" $file
        done
}

function configure_cpu_hostName {
        findfile="grep -lr computeHostName /etc"
        files=$(ssh_cpu $findfile)
        for file in $files; do
            ssh_cpu sed -i \"s/computeHostName/${ComputeHostName}/g\" $file
        done
}

function configure_cpu_myIP {
        findfile="grep -lr computeNodeMyIP /etc"
        files=$(ssh_cpu $findfile)
        for file in $files; do
            ssh_cpu sed -i \"s/computeNodeMyIP/${VMIP}/g\" $file
        done
}

function prepare_cpu_node_entry {
	import_cpu
	start_cpu
	get_xva_ip
	write_config
	configure_cpu_hostIP
	configure_cpu_controllerIP
	configure_cpu_hostName
	configure_cpu_myIP
}

