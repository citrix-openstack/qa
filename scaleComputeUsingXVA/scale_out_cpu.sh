#!/bin/bash
set -ex

tmp_path=$(mktemp -d)
CNODE_INFO_FILE=$tmp_path/cnode_info.txt
host_inv_path=''
controller_ip=''

# the format of compute node information should like:
# host_ip: XENSERVER_IP_ADDR1 cnode_ip: CPU_IP_ADDR1
# host_ip: XENSERVER_IP_ADDR2 cnode_ip: CPU_IP_ADDR2
# ...
echo "cnode_ip: CPU_IP_ADDR" > $CNODE_INFO_FILE

REMAINING_OPTIONS="$#"
while getopts ":i:p:" flag; do
    REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
    case "$flag" in
        i)
            host_inv_path="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        p)rm
            controller_ip="$OPTARG"
            REMAINING_OPTIONS=$(expr "$REMAINING_OPTIONS" - 1)
            ;;
        \?)
            echo "Unexpected argument"
            exit -1
    esac
done

if [ ! -f ssh_key.priv ]
then
    yes | ssh-keygen -t rsa -N "" -f ssh_key.priv
fi

# Set up internal variables
_SSH_OPTIONS="\
    -o BatchMode=yes \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i ssh_key.priv"

# input the server ip, username and password to acheive no pwd access
function create_no_pwd_access() {
    username=$2
    server_ip=$1
    password=$3
    sshpass -p $password \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $username@$server_ip "if [ ! -f ~/.ssh/authorized_keys ]; then mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys; fi"
    PUBKEY=$(cat ssh_key.priv.pub)
    sshpass -p $password \
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $username@$server_ip "echo $PUBKEY >> ~/.ssh/authorized_keys"
}
# excute remote shell on no pwd host
function on_no_pwd_host() {
    username=$2
    server_ip=$1
    ssh $_SSH_OPTIONS "$username@$server_ip" bash -s --
}

source prepare_cpu_node.sh # managed by liang
source config_cpu_node.sh

prepare_cpu_node_entry # managed by liang
config_cnode_entry
echo $?
set -x

source ./readconfig.sh

    CNODE_USER=$(readIni config.ini ComputeNode user)
    CNODE_PWD=$(readIni config.ini ComputeNode password)
    cnode_ip=$(readIni config.ini ComputeNode ip)
    host_ip=$(readIni config.ini ComputeHost ip)

on_no_pwd_host $cnode_ip $CNODE_USER <<CMDEND
set -x
# service start staff
service_list=\$(ls -al /etc/systemd/system | grep devstack@ | awk '{ print \$9 }')
for srv in \$service_list
do
    systemctl enable \$srv 2>&1 | tee -a /tmp/test.wjh
    systemctl start \$srv
done
CMDEND
#nova-manage cell_v2 simple_cell_setup
/opt/stack/devstack/tools/discover_hosts.sh > /tmp/dis.log
# verify staff
# log staff

rm -rf $tmp_path
