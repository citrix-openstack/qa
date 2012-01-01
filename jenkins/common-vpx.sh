thisdir=$(dirname $(readlink -f "$0"))

declare -a on_exit_hooks

on_exit()
{
    for i in "${on_exit_hooks[@]}"
    do
        eval $i
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]
    then
        trap on_exit EXIT
    fi
}

get_os_svc_property()
{
  local master_url="$1"
  local service="$2"
  local prop_label="$3"
  "$thisdir/utils/get_worker_vpx" "$master_url" "$service" "$prop_label"
}

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

upload_key()
{
  host="$1"
  if [ "$password" = '' ]
  then
    cat "$keyfile.pub" | \
      ssh_no_hosts root@$host \
          'mkdir -p /root/.ssh; cat >>/root/.ssh/authorized_keys'
  else
    key=$(cat "$keyfile.pub")
    expect >/dev/null <<EOF -
set timeout -1
spawn ssh -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o LogLevel=ERROR \
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
  fi
}
