#$1 is the tmp directory where py files have been copied
#$2 is the address of the worker
#$3 is the module with the tests
#$4:x are the parameters for the ptyhon test module
echo $1
echo $2
echo $3

declare -a on_exit_hooks

TESTDIR=~/test_multinic
thisdir=$(dirname "$0")

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

gen_key()
{
    ssh-keygen -N '' -f "$keyfile" >/dev/null
}

remote_gen_key()
{
    host=$1
    key_file=$2
    ssh_no_hosts root@$host "ssh-keygen -f /root/.ssh/$key_file -N '' ">/dev/null
}

upload_key()
{
    host="$1"
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

parse_result()
{
    local code="$1"
    [ "$code" -eq 0 ] && result_img="ok.png" || result_img="ko.png"
    cp "$thisdir/utils/imgs/$result_img" "$thisdir/screenshot_$result_img"
    echo $code
}

py_dir=$1
worker_vpx=$2
test_script=$3
test_args=${@:4}
keyfile=~/.ssh/id_rsa
password="citrix"
if [ ! -f $keyfile ]
then
    gen_key
fi
upload_key $worker_vpx

#copy files to the worker VPX ($worker_vpx)
set -x
tmpdir=$(ssh_no_hosts root@$worker_vpx "mktemp -d")
scp_no_hosts $py_dir/*.py root@$worker_vpx:$tmpdir 
add_on_exit "ssh_no_hosts root@$worker_vpx rm -rf $tmpdir"
# generate a key on the network worker and inject it in all other instances
ssh_no_hosts root@$worker_vpx mkdir -p /root/.ssh
scp_no_hosts $py_dir/key_injector.sh root@$worker_vpx:$tmpdir/key_injector.sh
ssh_no_hosts root@$worker_vpx $tmpdir/key_injector.sh /root/.ssh/key_worker
add_on_exit "ssh_no_hosts root@$worker_vpx rm /root/.ssh/key_worker*"
# generate a key on network worker for instances
key_name=key_4_tests
remote_gen_key $worker_vpx $key_name
ssh_no_hosts root@$worker_vpx chmod 0600 /root/.ssh/${key_name}*
add_on_exit "ssh_no_hosts root@$worker_vpx rm /root/.ssh/${key_name}*" 
# execute tests on network worker
echo "Running python tests..."
ssh_no_hosts root@$worker_vpx /usr/bin/python26 $tmpdir/$test_script $key_name $test_args
code=$(parse_result "$?")
# execute on exit hooks
exit $code
set +x