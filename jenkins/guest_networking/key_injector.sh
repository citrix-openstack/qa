# This script will generate a key on the worker VPX and inject it in all the VPXs

upload_key()
{
    host="$1"
    key=$(cat "${keyfile}.pub")
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

keyfile=$1
password="citrix"
ssh-keygen -f $keyfile -N ''
output=$(os-vpx-roles -s | awk {'print $2'} | uniq)
out_array=( $output )
for item in "${out_array[@]}"
do
    echo "item:" $item
    upload_key $item
done
