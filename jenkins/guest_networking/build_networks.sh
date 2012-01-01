# This script simply builds a VLAN network on a xenserver host

remote_xe_min()
{
  local host="$1"
  local cmd="$2"
  shift 2
  ssh root@$host "xe $cmd --minimal $@"
}

create_network()
{
  # creates a vlan network
  local host="$1"
  local pif_uuid="$2"
  local tag="$3"
  local net_label="$4"
  
  net_uuid=$(remote_xe_min $host network-create name-label=$net_label)
  remote_xe_min $host vlan-create pif-uuid=$pif_uuid network-uuid=$net_uuid vlan=$tag
  [ "$?" != "0" ] && echo "Unable to create VLAN! Exiting" && exit 1
  echo $net_uuid 
}

fetch_network()
{
  # retrieves network and assigns label to it
  local host="$1"
  local pif_uuid="$2"
  local net_label="$3"
  net_uuid=$(remote_xe_min $xs_host pif-list uuid=$vlan_pif_uuid params=network-uuid)
  remote_xe_min $host network-param-set uuid=$net_uuid name-label=$net_label
  [ "$?" != "0" ] && echo "Unable to set network label! Exiting" && exit 1 
  echo $net_uuid
}

check_exit_code()
{
  code=$1
  [ "$code" != "0" ] && exit $code
}

set -x
#Grab command line parameters
xs_host=$1
nic=$2
vlan_id=$3
net_label=$4

#ssh into host and verify whether VLAN already exists
if [ "$vlan_id" != "0" ]; then
  echo "Creating VLAN ID "$vlan_id" on host "$xs_host
  vlan_pif_uuid=$(remote_xe_min $xs_host "vlan-list params=untagged-PIF tag=$vlan_id")
else
  echo "Fetching bridge for nic "$nic" on host "$xs_host
  vlan_pif_uuid=$(remote_xe_min $xs_host "pif-list params=uuid device=$nic VLAN=-1")
fi
# If network already exists just return it
# TODO: Check PIF is correct
[ "$vlan_pif_uuid" != "" ] && fetch_network $xs_host $vlan_pif_uuid $net_label && exit

# VLAN does not exist, find PIF for NIC
# TODO: If PIF not found, introduce it
pif_uuid=$(remote_xe_min $xs_host pif-list device=$nic VLAN=-1)
# Now create network, and associate network with pid and vlan tag
net_uuid=$(create_network $xs_host $pif_uuid $vlan_id $net_label)
check_exit_code $?

# Return network
set +x
echo $net_uuid
