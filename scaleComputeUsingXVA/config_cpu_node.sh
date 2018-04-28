#!/bin/bash
set -x

source ./readconfig.sh

set -x

function init_conf_info() {
    CNODE_USER=$(readIni config.ini ComputeNode user)
    CNODE_PWD=$(readIni config.ini ComputeNode password)
    cnode_ip=$(readIni config.ini ComputeNode ip)
    host_ip=$(readIni config.ini ComputeHost ip)
    ctl_ip=$(readIni config.ini ControlNode ip)
}

function config_cnode_entry() {
    set -ex
    if [ ! -f $CNODE_INFO_FILE ]; then
        exit -1
    fi
    echo $CNODE_INFO_FILE
    init_conf_info
    for ip in  $cnode_ip
    do
        echo $cnode_ip
        create_no_pwd_access $cnode_ip $CNODE_USER $CNODE_PWD
        on_no_pwd_host $cnode_ip $CNODE_USER << CONFIG_CNODE_BLOCK
if ! sudo ls ~root/.ssh;
then
    sudo mkdir -p ~root/.ssh/
fi
CONFIG_CNODE_BLOCK

        scp $_SSH_OPTIONS ssh_key.priv root@$ip:/root/.ssh/id_rsa
        scp $_SSH_OPTIONS ssh_key.priv.pub root@$ip:/root/.ssh/id_rsa.pub

        create_no_pwd_access $host_ip root xenroot
        on_no_pwd_host $cnode_ip $CNODE_USER << CONFIG_CNODE_BLOCK

set +e
set -x
sudo sed -i "s/10.62.66.6/$ctl_ip/g" \`grep 10.62.66.6 -rl /etc/\`
DEST=/opt/stack XENAPI_CONNECTION_URL="http://$host_ip" DOMZERO_USER='root' /opt/stack/os-xenapi/devstack/plugin.sh 'stack' install
CONFIG_CNODE_BLOCK

done
}
