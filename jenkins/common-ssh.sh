# This library has common ssh functions that other code could use.

_no_hosts()
{
    cmd="$1"
    shift
    "$cmd" -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -i "$keyfile" \
        "$@"
}

ssh_no_hosts()
{
    _no_hosts "ssh" "$@"
}

scp_no_hosts()
{
    _no_hosts "scp" "$@"
}

gen_key()
{
    ssh-keygen -N '' -f "$keyfile" >/dev/null
    add_on_exit "rm -f $keyfile"
    add_on_exit "rm -f $keyfile.pub"
}


## 
##VOLWORKER=`os-vpx-get-worker-for volume`
##upload_key $VOLWORKER
##
upload_key()
{
    host="$1"
    password="$2"
    keyfile="$3"
    user=${4:-"root"}
    if [ $user == "root" ]
    then
        homedir="/root"
    elif [ $user == "stack" ]
    then
        homedir="/opt/stack"
    else
        homedir="/home/$user"
    fi
    key=$(cat "$keyfile.pub")
    expect -d <<EOF -
set timeout -1
spawn ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
          $user@$host \
          mkdir -p $homedir/.ssh\; echo $key >>$homedir/.ssh/authorized_keys
match_max 100000
expect {
    "*?assword:*" {
    send -- "$password\r"
    send -- "\r"
    expect eof
    }
    eof {
    }
EOF
}

upload_key_to_vpx()
{
    host="$1"
    password="$2"
    keyfile="$3"
    local_tunnel_port="$4"
    key=$(cat "$keyfile.pub")
    expect >/dev/null <<EOF -
set timeout -1
spawn ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
	  -p $local_tunnel_port \
          root@$host \
          mkdir -p /root/.ssh\; echo $key >>/root/.ssh/authorized_keys
match_max 100000
expect {
    "*?assword:*" {
    send -- "$password\r"
    send -- "\r"
    expect eof
    }
    eof {
    }
EOF
}
